const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const decimal = require('../utils/decimal');
const { nextReference } = require('../utils/references');
const { serializePurchase, serializePurchaseItem } = require('../utils/serialize');
const { paginationMeta } = require('../utils/pagination');
const purchaseRepository = require('../repositories/purchase.repository');
const stockService = require('./stock.service');

function normalizeItems(items) {
  return items.map((item) => {
    const quantity = decimal.toDecimal(item.quantity);
    const unitPrice = decimal.toDecimal(item.unitPrice);
    return {
      productId: item.productId,
      quantity,
      unitPrice,
      totalPrice: quantity.times(unitPrice),
    };
  });
}

function sumTotals(items) {
  return items.reduce((acc, item) => acc.plus(item.totalPrice), decimal.toDecimal(0));
}

function sortItems(items) {
  return [...items].sort((a, b) => a.productId.localeCompare(b.productId));
}

async function reversePurchaseItems(tx, purchase, userId, reason) {
  for (const item of sortItems(purchase.items)) {
    await stockService.decreaseStock(tx, {
      productId: item.productId,
      type: 'RETURN_PURCHASE',
      quantity: item.quantity,
      referenceType: 'RETURN',
      referenceId: purchase.id,
      reason,
      createdById: userId,
    });
  }
}

async function assertSupplier(supplierId) {
  const supplier = await prisma.supplier.findUnique({ where: { id: supplierId } });
  if (!supplier || !supplier.isActive) {
    throw ApiError.badRequest('Supplier not found or inactive');
  }
  return supplier;
}

async function assertProducts(items) {
  const ids = [...new Set(items.map((item) => item.productId))];
  const products = await prisma.product.findMany({
    where: { id: { in: ids } },
  });
  if (products.length !== ids.length) {
    throw ApiError.badRequest('One or more products were not found');
  }
  const inactive = products.find((product) => !product.isActive);
  if (inactive) {
    throw ApiError.badRequest(`Product ${inactive.name} is inactive`);
  }
}

function parseDate(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) {
    throw ApiError.badRequest('Invalid date');
  }
  return date;
}

async function listPurchases(query) {
  const { page, pageSize, search, supplierId, status, from, to } = query;
  const { items, total } = await purchaseRepository.findMany({
    skip: (page - 1) * pageSize,
    take: pageSize,
    search,
    supplierId,
    status,
    from: from ? new Date(from) : undefined,
    to: to ? new Date(to) : undefined,
  });

  return {
    items: items.map(serializePurchase),
    pagination: paginationMeta(total, page, pageSize),
  };
}

async function getPurchase(id) {
  const purchase = await purchaseRepository.findById(id);
  if (!purchase) {
    throw ApiError.notFound('Purchase not found');
  }
  return serializePurchase(purchase);
}

async function listPurchaseItems(id) {
  const purchase = await purchaseRepository.findById(id);
  if (!purchase) {
    throw ApiError.notFound('Purchase not found');
  }
  return purchase.items.map(serializePurchaseItem);
}

async function createPurchase(payload, userId) {
  await assertSupplier(payload.supplierId);
  const items = normalizeItems(payload.items);
  await assertProducts(items);

  if (payload.referenceNumber) {
    const existing = await purchaseRepository.findByReference(payload.referenceNumber);
    if (existing) {
      throw ApiError.conflict('A purchase with this reference already exists');
    }
  }

  const purchase = await prisma.$transaction(async (tx) => {
    await stockService.lockProductsInOrder(tx, stockService.uniqueSortedProductIds(items));

    const referenceNumber =
      payload.referenceNumber || (await nextReference(tx, 'purchase', 'ACH'));

    const created = await tx.purchase.create({
      data: {
        supplierId: payload.supplierId,
        referenceNumber,
        purchaseDate: parseDate(payload.purchaseDate),
        totalAmount: sumTotals(items),
        notes: payload.notes,
        status: 'CONFIRMED',
      },
    });

    const supplierId = payload.supplierId;
    for (const item of sortItems(items)) {
      await tx.purchaseItem.create({
        data: {
          purchaseId: created.id,
          productId: item.productId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
        },
      });

      await stockService.increaseStock(tx, {
        productId: item.productId,
        type: 'PURCHASE',
        quantity: item.quantity,
        referenceType: 'PURCHASE',
        referenceId: created.id,
        createdById: userId,
      });

      await tx.productSupplier.upsert({
        where: {
          productId_supplierId: { productId: item.productId, supplierId },
        },
        update: { lastPurchasePrice: item.unitPrice },
        create: {
          productId: item.productId,
          supplierId,
          lastPurchasePrice: item.unitPrice,
        },
      });
    }

    return purchaseRepository.findById(created.id, tx);
  });

  return serializePurchase(purchase);
}

async function updatePurchase(id, payload, userId) {
  const existing = await purchaseRepository.findById(id);
  if (!existing) {
    throw ApiError.notFound('Purchase not found');
  }
  if (existing.status === 'CANCELLED') {
    throw ApiError.conflict('Cannot update a cancelled purchase');
  }

  if (payload.supplierId) {
    await assertSupplier(payload.supplierId);
  }

  if (payload.referenceNumber && payload.referenceNumber !== existing.referenceNumber) {
    const duplicate = await purchaseRepository.findByReference(payload.referenceNumber);
    if (duplicate) {
      throw ApiError.conflict('A purchase with this reference already exists');
    }
  }

  const purchase = await prisma.$transaction(async (tx) => {
    const current = await tx.purchase.findUnique({ where: { id } });
    if (!current || current.status === 'CANCELLED') {
      throw ApiError.conflict('Cannot update a cancelled purchase');
    }

    if (payload.items) {
      const items = normalizeItems(payload.items);
      await assertProducts(items);
      await stockService.lockProductsInOrder(
        tx,
        stockService.uniqueSortedProductIds([...existing.items, ...items])
      );
      await reversePurchaseItems(
        tx,
        existing,
        userId,
        `Modification de l'achat ${existing.referenceNumber}`
      );
      await tx.purchaseItem.deleteMany({ where: { purchaseId: id } });

      const supplierId = payload.supplierId || existing.supplierId;
      for (const item of sortItems(items)) {
        await tx.purchaseItem.create({
          data: {
            purchaseId: id,
            productId: item.productId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
          },
        });
        await stockService.increaseStock(tx, {
          productId: item.productId,
          type: 'PURCHASE',
          quantity: item.quantity,
          referenceType: 'PURCHASE',
          referenceId: id,
          createdById: userId,
        });
        await tx.productSupplier.upsert({
          where: { productId_supplierId: { productId: item.productId, supplierId } },
          update: { lastPurchasePrice: item.unitPrice },
          create: {
            productId: item.productId,
            supplierId,
            lastPurchasePrice: item.unitPrice,
          },
        });
      }

      await tx.purchase.update({
        where: { id },
        data: {
          supplierId: payload.supplierId,
          referenceNumber: payload.referenceNumber,
          purchaseDate: payload.purchaseDate ? parseDate(payload.purchaseDate) : undefined,
          notes: payload.notes,
          totalAmount: sumTotals(items),
        },
      });
    } else {
      await tx.purchase.update({
        where: { id },
        data: {
          supplierId: payload.supplierId,
          referenceNumber: payload.referenceNumber,
          purchaseDate: payload.purchaseDate ? parseDate(payload.purchaseDate) : undefined,
          notes: payload.notes,
        },
      });
    }

    return purchaseRepository.findById(id, tx);
  });

  return serializePurchase(purchase);
}

async function cancelPurchase(id, userId, reason) {
  const existing = await purchaseRepository.findById(id);
  if (!existing) {
    throw ApiError.notFound('Purchase not found');
  }
  if (existing.status === 'CANCELLED') {
    throw ApiError.conflict('Purchase is already cancelled');
  }

  const purchase = await prisma.$transaction(async (tx) => {
    const current = await tx.purchase.findUnique({ where: { id } });
    if (!current || current.status === 'CANCELLED') {
      throw ApiError.conflict('Purchase is already cancelled');
    }

    await stockService.lockProductsInOrder(
      tx,
      stockService.uniqueSortedProductIds(existing.items)
    );

    await reversePurchaseItems(
      tx,
      existing,
      userId,
      reason || `Annulation de l'achat ${existing.referenceNumber}`
    );

    await tx.purchase.update({
      where: { id },
      data: {
        status: 'CANCELLED',
        cancelledAt: new Date(),
        cancelReason: reason || 'Annulation',
      },
    });

    return purchaseRepository.findById(id, tx);
  });

  return serializePurchase(purchase);
}

module.exports = {
  listPurchases,
  getPurchase,
  listPurchaseItems,
  createPurchase,
  updatePurchase,
  cancelPurchase,
};
