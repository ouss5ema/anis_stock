const { ApiError } = require('../utils/ApiError');
const { ErrorCodes } = require('../utils/errorCodes');
const decimal = require('../utils/decimal');

function uniqueSortedProductIds(items) {
  return [...new Set(items.map((item) => item.productId))].sort();
}

async function lockProduct(tx, productId) {
  const rows = await tx.$queryRaw`
    SELECT id, name, sku, "currentStock", "isActive"
    FROM products
    WHERE id = ${productId}
    FOR UPDATE
  `;

  if (!rows.length) {
    throw ApiError.notFound('Product not found');
  }

  return rows[0];
}

async function lockProductsInOrder(tx, productIds) {
  const locked = [];
  for (const productId of [...productIds].sort()) {
    locked.push(await lockProduct(tx, productId));
  }
  return locked;
}

async function applyMovement(tx, {
  productId,
  type,
  direction,
  quantity,
  referenceType,
  referenceId,
  reason,
  createdById,
}) {
  const qty = decimal.toDecimal(quantity);
  if (qty.lessThanOrEqualTo(0)) {
    throw ApiError.badRequest('Quantity must be greater than 0');
  }

  const product = await lockProduct(tx, productId);
  const previousStock = decimal.toDecimal(product.currentStock);
  const newStock = direction === 'in' ? previousStock.plus(qty) : previousStock.minus(qty);

  if (newStock.isNegative()) {
    // Message kept as-is (parsed by the mobile app); `code` added for clients.
    throw ApiError.badRequest(
      `Insufficient stock for ${product.name}. Available: ${previousStock.toFixed(3)}, requested: ${qty.toFixed(3)}`,
      [
        {
          productId,
          productName: product.name,
          available: previousStock.toFixed(3),
          requested: qty.toFixed(3),
        },
      ],
      ErrorCodes.INSUFFICIENT_STOCK
    );
  }

  const movement = await tx.stockMovement.create({
    data: {
      productId,
      type,
      quantity: qty,
      previousStock,
      newStock,
      referenceType,
      referenceId,
      reason,
      createdById,
    },
  });

  await tx.product.update({
    where: { id: productId },
    data: { currentStock: newStock },
  });

  return {
    movement,
    previousStock,
    newStock,
    product,
  };
}

async function increaseStock(tx, params) {
  return applyMovement(tx, { ...params, direction: 'in' });
}

async function decreaseStock(tx, params) {
  return applyMovement(tx, { ...params, direction: 'out' });
}

module.exports = {
  lockProduct,
  lockProductsInOrder,
  uniqueSortedProductIds,
  applyMovement,
  increaseStock,
  decreaseStock,
};
