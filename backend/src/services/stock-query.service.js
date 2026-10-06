const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const decimal = require('../utils/decimal');
const { serializeStockMovement } = require('../utils/serialize');
const { paginationMeta } = require('../utils/pagination');
const stockRepository = require('../repositories/stock.repository');
const stockService = require('./stock.service');

const movementTypes = [
  'PURCHASE',
  'SALE',
  'ADJUSTMENT_IN',
  'ADJUSTMENT_OUT',
  'RETURN_PURCHASE',
  'RETURN_SALE',
];

async function listMovements(query) {
  const { page, pageSize, productId, type, from, to } = query;
  if (type && !movementTypes.includes(type)) {
    throw ApiError.badRequest('Invalid movement type');
  }

  const { items, total } = await stockRepository.findMany({
    skip: (page - 1) * pageSize,
    take: pageSize,
    productId,
    type,
    from: from ? new Date(from) : undefined,
    to: to ? new Date(to) : undefined,
  });

  return {
    items: items.map(serializeStockMovement),
    pagination: paginationMeta(total, page, pageSize),
  };
}

async function adjustStock(payload, userId) {
  const quantity = decimal.toDecimal(payload.quantity);
  if (quantity.lessThanOrEqualTo(0)) {
    throw ApiError.badRequest('Quantity must be greater than 0');
  }

  const direction = payload.direction;
  if (!['in', 'out'].includes(direction)) {
    throw ApiError.badRequest('Direction must be in or out');
  }

  const reason = payload.reason?.trim();
  if (!reason) {
    throw ApiError.badRequest('A reason is required for stock adjustments');
  }

  const result = await prisma.$transaction(async (tx) => {
    return stockService.applyMovement(tx, {
      productId: payload.productId,
      type: direction === 'in' ? 'ADJUSTMENT_IN' : 'ADJUSTMENT_OUT',
      direction,
      quantity,
      referenceType: 'ADJUSTMENT',
      reason,
      createdById: userId,
    });
  });

  return serializeStockMovement({
    ...result.movement,
    product: {
      id: result.product.id,
      sku: result.product.sku,
      name: result.product.name,
    },
  });
}

module.exports = {
  listMovements,
  adjustStock,
};
