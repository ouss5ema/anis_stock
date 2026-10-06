const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const decimal = require('../utils/decimal');
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
  for (const item of sortItems(sale.items)) {
    await stockService.increaseStock(tx, {
      productId: item.productId,
      type: 'RETURN_SALE',
      quantity: item.quantity,
      referenceType: 'RETURN',
      referenceId: sale.id,
      reason,
      createdById: userId,
    });
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
  const existing = await saleRepository.findById(id);
  if (!existing) {
    throw ApiError.notFound('Sale not found');
  }
  if (existing.status === 'CANCELLED') {
    throw ApiError.conflict('Cannot update a cancelled sale');
  }

  if (payload.customerId) {
    await assertCustomer(payload.customerId);
  }

  if (payload.referenceNumber && payload.referenceNumber !== existing.referenceNumber) {
    const duplicate = await saleRepository.findByReference(payload.referenceNumber);
    if (duplicate) {
      throw ApiError.conflict('A sale with this reference already exists');
    }
  }

  const sale = await prisma.$transaction(async (tx) => {
    const current = await tx.sale.findUnique({ where: { id } });
    if (!current || current.status === 'CANCELLED') {
      throw ApiError.conflict('Cannot update a cancelled sale');
    }

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

    return saleRepository.findById(id, tx);
  });

  return serializeSale(sale);
}

async function cancelSale(id, userId, reason) {
  const existing = await saleRepository.findById(id);
  if (!existing) {
    throw ApiError.notFound('Sale not found');
  }
  if (existing.status === 'CANCELLED') {
    throw ApiError.conflict('Sale is already cancelled');
  }

  const sale = await prisma.$transaction(async (tx) => {
    const current = await tx.sale.findUnique({ where: { id } });
    if (!current || current.status === 'CANCELLED') {
      throw ApiError.conflict('Sale is already cancelled');
    }

    await reverseSaleItems(
      tx,
      existing,
      userId,
      reason || `Annulation de la vente ${existing.referenceNumber}`
    );
    await tx.sale.update({
      where: { id },
      data: {
        status: 'CANCELLED',
        cancelledAt: new Date(),
        cancelReason: reason || 'Annulation',
      },
    });
    return saleRepository.findById(id, tx);
  });

  return serializeSale(sale);
}

module.exports = {
  listSales,
  getSale,
  listSaleItems,
  createSale,
  updateSale,
  cancelSale,
};
