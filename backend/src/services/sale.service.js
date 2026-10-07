const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const { ErrorCodes } = require('../utils/errorCodes');
const decimal = require('../utils/decimal');
const audit = require('./audit.service');
const { nextReference } = require('../utils/references');
const { serializeSale, serializeSaleItem } = require('../utils/serialize');
const { paginationMeta } = require('../utils/pagination');
const saleRepository = require('../repositories/sale.repository');
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

function parseDate(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) {
    throw ApiError.badRequest('Invalid date');
  }
  return date;
}

async function assertCustomer(customerId) {
  const customer = await prisma.customer.findUnique({ where: { id: customerId } });
  if (!customer || !customer.isActive) {
    throw ApiError.badRequest('Customer not found or inactive');
  }
  return customer;
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

function sortItems(items) {
  return [...items].sort((a, b) => a.productId.localeCompare(b.productId));
}

async function applySaleItems(tx, saleId, items, userId) {
  for (const item of sortItems(items)) {
    await tx.saleItem.create({
      data: {
        saleId,
        productId: item.productId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalPrice: item.totalPrice,
      },
    });

    await stockService.decreaseStock(tx, {
      productId: item.productId,
      type: 'SALE',
      quantity: item.quantity,
      referenceType: 'SALE',
      referenceId: saleId,
      createdById: userId,
    });
  }
}

async function reverseSaleItems(tx, sale, userId, reason) {
  const results = [];
  for (const item of sortItems(sale.items)) {
    results.push(
      await stockService.increaseStock(tx, {
        productId: item.productId,
        type: 'RETURN_SALE',
        quantity: item.quantity,
        referenceType: 'RETURN',
        referenceId: sale.id,
        reason,
        createdById: userId,
      })
    );
  }
  return results;
}

/**
 * Locks the sale row for the rest of the transaction and refuses a cancelled
 * sale. Lock order is always: document row first, then products (sorted).
 */
async function lockConfirmedSale(tx, id) {
  const rows = await tx.$queryRaw`SELECT id, status FROM sales WHERE id = ${id} FOR UPDATE`;
  if (!rows.length) {
    throw ApiError.notFound('Vente introuvable');
  }
  if (rows[0].status === 'CANCELLED') {
    throw ApiError.conflict('Impossible de modifier une vente annulée', [], ErrorCodes.DOCUMENT_CANCELLED);
  }
}

async function listSales(query) {
  const { page, pageSize, search, customerId, status, from, to } = query;
  const { items, total } = await saleRepository.findMany({
    skip: (page - 1) * pageSize,
    take: pageSize,
    search,
    customerId,
    status,
    from: from ? new Date(from) : undefined,
    to: to ? new Date(to) : undefined,
  });

  return {
    items: items.map(serializeSale),
    pagination: paginationMeta(total, page, pageSize),
  };
}

async function getSale(id) {
  const sale = await saleRepository.findById(id);
  if (!sale) {
    throw ApiError.notFound('Sale not found');
  }
  return serializeSale(sale);
}

async function listSaleItems(id) {
  const sale = await saleRepository.findById(id);
  if (!sale) {
    throw ApiError.notFound('Sale not found');
  }
  return sale.items.map(serializeSaleItem);
}

async function createSale(payload, userId) {
  await assertCustomer(payload.customerId);
  const items = normalizeItems(payload.items);
  await assertProducts(items);

  if (payload.referenceNumber) {
    const existing = await saleRepository.findByReference(payload.referenceNumber);
    if (existing) {
      throw ApiError.conflict('A sale with this reference already exists');
    }
  }

  const sale = await prisma.$transaction(async (tx) => {
    await stockService.lockProductsInOrder(tx, stockService.uniqueSortedProductIds(items));
    const referenceNumber = payload.referenceNumber || (await nextReference(tx, 'sale', 'VEN'));

    const created = await tx.sale.create({
      data: {
        customerId: payload.customerId,
        referenceNumber,
        saleDate: parseDate(payload.saleDate),
        totalAmount: sumTotals(items),
        notes: payload.notes,
        status: 'CONFIRMED',
      },
    });

    await applySaleItems(tx, created.id, items, userId);
    return saleRepository.findById(created.id, tx);
  });

  return serializeSale(sale);
}

async function updateSale(id, payload, userId) {
  const found = await saleRepository.findById(id);
  if (!found) {
    throw ApiError.notFound('Vente introuvable');
  }
  if (found.status === 'CANCELLED') {
    throw ApiError.conflict('Impossible de modifier une vente annulée', [], ErrorCodes.DOCUMENT_CANCELLED);
  }

  if (payload.customerId) {
    await assertCustomer(payload.customerId);
  }

  if (payload.referenceNumber && payload.referenceNumber !== found.referenceNumber) {
    const duplicate = await saleRepository.findByReference(payload.referenceNumber);
    if (duplicate) {
      throw ApiError.conflict('A sale with this reference already exists');
    }
  }

  const sale = await prisma.$transaction(async (tx) => {
    // Checked again under lock: a concurrent cancellation wins or waits.
    await lockConfirmedSale(tx, id);
    const existing = await saleRepository.findById(id, tx);

    if (payload.items) {
      const items = normalizeItems(payload.items);
      await assertProducts(items);
      await stockService.lockProductsInOrder(
        tx,
        stockService.uniqueSortedProductIds([...existing.items, ...items])
      );
      await reverseSaleItems(tx, existing, userId, `Modification de la vente ${existing.referenceNumber}`);
      await tx.saleItem.deleteMany({ where: { saleId: id } });
      await applySaleItems(tx, id, items, userId);
      await tx.sale.update({
        where: { id },
        data: {
          customerId: payload.customerId,
          referenceNumber: payload.referenceNumber,
          saleDate: payload.saleDate ? parseDate(payload.saleDate) : undefined,
          notes: payload.notes,
          totalAmount: sumTotals(items),
        },
      });
    } else {
      await tx.sale.update({
        where: { id },
        data: {
          customerId: payload.customerId,
          referenceNumber: payload.referenceNumber,
          saleDate: payload.saleDate ? parseDate(payload.saleDate) : undefined,
          notes: payload.notes,
        },
      });
    }

    const updated = await saleRepository.findById(id, tx);
    await audit.record(tx, {
      action: 'SALE_UPDATED',
      entityType: 'SALE',
      entityId: id,
      entityLabel: updated.referenceNumber,
      userId,
      metadata: {
        before: {
          customerId: existing.customerId,
          saleDate: existing.saleDate,
          totalAmount: decimal.toString(existing.totalAmount),
          lines: audit.describeLines(existing.items),
        },
        after: {
          customerId: updated.customerId,
          saleDate: updated.saleDate,
          totalAmount: decimal.toString(updated.totalAmount),
          lines: audit.describeLines(updated.items),
        },
      },
    });
    return updated;
  });

  return serializeSale(sale);
}

/**
 * Cancels a sale: one RETURN_SALE movement per line through applyMovement,
 * all in one transaction. The conditional update on status CONFIRMED is the
 * concurrency guard: a second concurrent cancellation waits for the row lock,
 * then matches 0 rows and is refused.
 */
async function cancelSale(id, userId, reason) {
  const sale = await prisma.$transaction(async (tx) => {
    const claimed = await tx.sale.updateMany({
      where: { id, status: 'CONFIRMED' },
      data: {
        status: 'CANCELLED',
        cancelledAt: new Date(),
        cancelReason: reason,
        cancelledById: userId ?? null,
      },
    });
    if (claimed.count === 0) {
      const exists = await tx.sale.findUnique({ where: { id }, select: { id: true } });
      if (!exists) {
        throw ApiError.notFound('Vente introuvable');
      }
      throw ApiError.conflict('Cette vente est déjà annulée', [], ErrorCodes.ALREADY_CANCELLED);
    }

    // Lines read inside the transaction, after the row is locked.
    const current = await saleRepository.findById(id, tx);
    const results = await reverseSaleItems(
      tx,
      current,
      userId,
      `Annulation de la vente ${current.referenceNumber} : ${reason}`
    );

    await audit.record(tx, {
      action: 'SALE_CANCELLED',
      entityType: 'SALE',
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

    return saleRepository.findById(id, tx);
  });

  return serializeSale(sale);
}

/** Indicative only: the cancellation transaction is authoritative. */
async function getCancelPreview(id) {
  const sale = await saleRepository.findById(id);
  if (!sale) {
    throw ApiError.notFound('Vente introuvable');
  }
  const totals = new Map();
  for (const item of sale.items) {
    const entry = totals.get(item.productId) || {
      productId: item.productId,
      productName: item.product?.name,
      unit: item.product?.unit,
      currentStock: decimal.toDecimal(item.product?.currentStock),
      quantity: decimal.toDecimal(0),
    };
    entry.quantity = entry.quantity.plus(item.quantity);
    totals.set(item.productId, entry);
  }
  const lines = [...totals.values()].map((entry) => ({
    productId: entry.productId,
    productName: entry.productName,
    unit: entry.unit,
    quantity: entry.quantity.toFixed(3),
    stockBefore: entry.currentStock.toFixed(3),
    stockAfter: entry.currentStock.plus(entry.quantity).toFixed(3),
    blocking: false,
  }));
  return {
    id: sale.id,
    referenceNumber: sale.referenceNumber,
    status: sale.status,
    canCancel: sale.status === 'CONFIRMED',
    blockingReason: sale.status === 'CANCELLED' ? 'Cette vente est déjà annulée' : null,
    lines,
  };
}

module.exports = {
  listSales,
  getSale,
  listSaleItems,
  createSale,
  updateSale,
  cancelSale,
  getCancelPreview,
};
