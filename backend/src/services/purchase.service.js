const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const { ErrorCodes } = require('../utils/errorCodes');
const { quantityFr } = require('../utils/frenchFormat');
const decimal = require('../utils/decimal');
const audit = require('./audit.service');
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
  const results = [];
  for (const item of sortItems(purchase.items)) {
    results.push(
      await stockService.decreaseStock(tx, {
        productId: item.productId,
        type: 'RETURN_PURCHASE',
        quantity: item.quantity,
        referenceType: 'RETURN',
        referenceId: purchase.id,
        reason,
        createdById: userId,
      })
    );
  }
  return results;
}

/** Quantity to remove per product (a product can appear on several lines). */
function quantitiesByProduct(items) {
  const totals = new Map();
  for (const item of items) {
    const entry = totals.get(item.productId) || {
      productId: item.productId,
      productName: item.product?.name,
      unit: item.product?.unit,
      quantity: decimal.toDecimal(0),
    };
    entry.quantity = entry.quantity.plus(item.quantity);
    totals.set(item.productId, entry);
  }
  return [...totals.values()];
}

/** Products whose current stock is lower than the quantity to remove. */
function findShortages(required, stockById) {
  return required
    .map((entry) => ({ ...entry, available: decimal.toDecimal(stockById.get(entry.productId)) }))
    .filter((entry) => entry.available.lessThan(entry.quantity));
}

function shortageMessage(reference, shortages) {
  const details = shortages
    .map(
      (entry) =>
        `le stock actuel de « ${entry.productName} » est de ${quantityFr(entry.available)}, il faudrait en retirer ${quantityFr(entry.quantity)}`
    )
    .join(' ; ');
  return `Impossible d'annuler l'achat ${reference} : ${details} (marchandise déjà vendue).`;
}

/** Locks the purchase row; refuses a cancelled purchase. Document first, then products. */
async function lockConfirmedPurchase(tx, id) {
  const rows = await tx.$queryRaw`SELECT id, status FROM purchases WHERE id = ${id} FOR UPDATE`;
  if (!rows.length) {
    throw ApiError.notFound('Achat introuvable');
  }
  if (rows[0].status === 'CANCELLED') {
    throw ApiError.conflict('Impossible de modifier un achat annulé', [], ErrorCodes.DOCUMENT_CANCELLED);
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
  const found = await purchaseRepository.findById(id);
  if (!found) {
    throw ApiError.notFound('Achat introuvable');
  }
  if (found.status === 'CANCELLED') {
    throw ApiError.conflict('Impossible de modifier un achat annulé', [], ErrorCodes.DOCUMENT_CANCELLED);
  }

  if (payload.supplierId) {
    await assertSupplier(payload.supplierId);
  }

  if (payload.referenceNumber && payload.referenceNumber !== found.referenceNumber) {
    const duplicate = await purchaseRepository.findByReference(payload.referenceNumber);
    if (duplicate) {
      throw ApiError.conflict('A purchase with this reference already exists');
    }
  }

  const purchase = await prisma.$transaction(async (tx) => {
    // Checked again under lock: a concurrent cancellation wins or waits.
    await lockConfirmedPurchase(tx, id);
    const existing = await purchaseRepository.findById(id, tx);

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

    const updated = await purchaseRepository.findById(id, tx);
    await audit.record(tx, {
      action: 'PURCHASE_UPDATED',
      entityType: 'PURCHASE',
      entityId: id,
      entityLabel: updated.referenceNumber,
      userId,
      metadata: {
        before: {
          supplierId: existing.supplierId,
          purchaseDate: existing.purchaseDate,
          totalAmount: decimal.toString(existing.totalAmount),
          lines: audit.describeLines(existing.items),
        },
        after: {
          supplierId: updated.supplierId,
          purchaseDate: updated.purchaseDate,
          totalAmount: decimal.toString(updated.totalAmount),
          lines: audit.describeLines(updated.items),
        },
      },
    });
    return updated;
  });

  return serializePurchase(purchase);
}

/**
 * Cancels a purchase with RETURN_PURCHASE movements through applyMovement.
 * Refused, with full rollback, if a product no longer has enough stock
 * (goods already sold). Same concurrency guard as sales.
 */
async function cancelPurchase(id, userId, reason) {
  const purchase = await prisma.$transaction(async (tx) => {
    const claimed = await tx.purchase.updateMany({
      where: { id, status: 'CONFIRMED' },
      data: {
        status: 'CANCELLED',
        cancelledAt: new Date(),
        cancelReason: reason,
        cancelledById: userId ?? null,
      },
    });
    if (claimed.count === 0) {
      const exists = await tx.purchase.findUnique({ where: { id }, select: { id: true } });
      if (!exists) {
        throw ApiError.notFound('Achat introuvable');
      }
      throw ApiError.conflict('Cet achat est déjà annulé', [], ErrorCodes.ALREADY_CANCELLED);
    }

    const current = await purchaseRepository.findById(id, tx);
    const locked = await stockService.lockProductsInOrder(
      tx,
      stockService.uniqueSortedProductIds(current.items)
    );
    const stockById = new Map(locked.map((product) => [product.id, product.currentStock]));
    const shortages = findShortages(quantitiesByProduct(current.items), stockById);
    if (shortages.length) {
      // Throwing rolls back the status change above as well.
      throw ApiError.conflict(
        shortageMessage(current.referenceNumber, shortages),
        shortages.map((entry) => ({
          productId: entry.productId,
          productName: entry.productName,
          available: entry.available.toFixed(3),
          required: entry.quantity.toFixed(3),
        })),
        ErrorCodes.INSUFFICIENT_STOCK
      );
    }

    const results = await reversePurchaseItems(
      tx,
      current,
      userId,
      `Annulation de l'achat ${current.referenceNumber} : ${reason}`
    );

    await audit.record(tx, {
      action: 'PURCHASE_CANCELLED',
      entityType: 'PURCHASE',
      entityId: id,
      entityLabel: current.referenceNumber,
      reason,
      userId,
      metadata: {
        reference: current.referenceNumber,
        totalAmount: decimal.toString(current.totalAmount),
        stock: audit.stockChanges(results),
      },
    });

    return purchaseRepository.findById(id, tx);
  });

  return serializePurchase(purchase);
}

/** Indicative only: the cancellation transaction is authoritative. */
async function getCancelPreview(id) {
  const purchase = await purchaseRepository.findById(id);
  if (!purchase) {
    throw ApiError.notFound('Achat introuvable');
  }
  const required = quantitiesByProduct(purchase.items);
  const stockById = new Map(purchase.items.map((item) => [item.productId, item.product?.currentStock]));
  const shortages = findShortages(required, stockById);
  const blockingIds = new Set(shortages.map((entry) => entry.productId));

  const lines = required.map((entry) => {
    const before = decimal.toDecimal(stockById.get(entry.productId));
    return {
      productId: entry.productId,
      productName: entry.productName,
      unit: entry.unit,
      quantity: entry.quantity.toFixed(3),
      stockBefore: before.toFixed(3),
      stockAfter: before.minus(entry.quantity).toFixed(3),
      blocking: blockingIds.has(entry.productId),
    };
  });

  let blockingReason = null;
  if (purchase.status === 'CANCELLED') {
    blockingReason = 'Cet achat est déjà annulé';
  } else if (shortages.length) {
    blockingReason = shortageMessage(purchase.referenceNumber, shortages);
  }

  return {
    id: purchase.id,
    referenceNumber: purchase.referenceNumber,
    status: purchase.status,
    canCancel: purchase.status === 'CONFIRMED' && shortages.length === 0,
    blockingReason,
    lines,
  };
}

module.exports = {
  listPurchases,
  getPurchase,
  listPurchaseItems,
  createPurchase,
  updatePurchase,
  cancelPurchase,
  getCancelPreview,
};
