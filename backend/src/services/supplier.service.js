const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const { serializeSupplier } = require('../utils/serialize');
const { paginationMeta } = require('../utils/pagination');
const decimal = require('../utils/decimal');
const supplierRepository = require('../repositories/supplier.repository');
const audit = require('./audit.service');

function normalizeEmail(email) {
  if (email === '' || email === undefined) {
    return null;
  }
  return email;
}

async function listSuppliers(query) {
  const { page, pageSize, search, includeInactive, type } = query;
  const skip = (page - 1) * pageSize;
  const { items, total } = await supplierRepository.findMany({
    skip,
    take: pageSize,
    search,
    includeInactive,
    type,
  });

  return {
    items: items.map(serializeSupplier),
    pagination: paginationMeta(total, page, pageSize),
  };
}

async function getSupplierStats(id) {
  const confirmed = { supplierId: id, status: 'CONFIRMED' };
  const [purchaseCount, agg, lastPurchase] = await Promise.all([
    prisma.purchase.count({ where: confirmed }),
    prisma.purchase.aggregate({
      where: confirmed,
      _sum: { totalAmount: true },
    }),
    prisma.purchase.findFirst({
      where: confirmed,
      orderBy: { purchaseDate: 'desc' },
      select: {
        id: true,
        purchaseDate: true,
        referenceNumber: true,
        totalAmount: true,
      },
    }),
  ]);

  return {
    purchaseCount,
    totalPurchased: decimal.toString(agg._sum.totalAmount || 0),
    lastPurchase: lastPurchase
      ? {
          id: lastPurchase.id,
          date: lastPurchase.purchaseDate,
          referenceNumber: lastPurchase.referenceNumber,
          totalAmount: decimal.toString(lastPurchase.totalAmount),
        }
      : null,
  };
}

async function getSupplier(id) {
  const supplier = await supplierRepository.findById(id);
  if (!supplier) {
    throw ApiError.notFound('Supplier not found');
  }
  return serializeSupplier({
    ...supplier,
    stats: await getSupplierStats(id),
  });
}

async function createSupplier(payload) {
  const { productIds, ...data } = payload;

  const supplier = await supplierRepository.create({
    ...data,
    email: normalizeEmail(data.email),
    products: productIds?.length
      ? {
          create: productIds.map((productId) => ({ productId })),
        }
      : undefined,
  });

  return serializeSupplier(supplier);
}

async function updateSupplier(id, payload) {
  const supplier = await supplierRepository.findById(id);
  if (!supplier) {
    throw ApiError.notFound('Supplier not found');
  }

  const { productIds, ...data } = payload;

  if (Object.prototype.hasOwnProperty.call(data, 'email')) {
    data.email = normalizeEmail(data.email);
  }

  if (productIds) {
    await supplierRepository.replaceProducts(id, productIds);
  }

  const updated = await supplierRepository.update(id, data);
  return serializeSupplier(updated);
}

/** Unchanged behavior (deactivation, never a physical delete) + audit entry. */
async function deleteSupplier(id, userId, reason) {
  const supplier = await supplierRepository.findById(id);
  if (!supplier) {
    throw ApiError.notFound('Supplier not found');
  }

  const updated = await supplierRepository.softDelete(id);
  await audit.record(null, {
    action: 'SUPPLIER_DELETED',
    entityType: 'SUPPLIER',
    entityId: id,
    entityLabel: supplier.name,
    reason,
    userId,
    metadata: { mode: 'DEACTIVATED' },
  });
  return serializeSupplier(updated);
}

module.exports = {
  listSuppliers,
  getSupplier,
  createSupplier,
  updateSupplier,
  deleteSupplier,
};
