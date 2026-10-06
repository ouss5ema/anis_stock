const { prisma } = require('../config/prisma');
const decimal = require('../utils/decimal');

const productInclude = {
  category: true,
  suppliers: {
    include: {
      supplier: {
        select: { id: true, name: true, type: true },
      },
    },
  },
};

function buildFilters({ search, includeInactive, categoryId }) {
  return {
    ...(includeInactive ? {} : { isActive: true }),
    ...(categoryId ? { categoryId } : {}),
    ...(search
      ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { sku: { contains: search, mode: 'insensitive' } },
            { description: { contains: search, mode: 'insensitive' } },
          ],
        }
      : {}),
  };
}

async function findMany({ skip, take, search, includeInactive, categoryId, lowStock, outOfStock }) {
  const filters = buildFilters({ search, includeInactive, categoryId });

  if (lowStock || outOfStock) {
    const all = await prisma.product.findMany({
      where: filters,
      include: productInclude,
      orderBy: { name: 'asc' },
    });
    const filtered = all.filter((product) => {
      const current = decimal.toDecimal(product.currentStock);
      const min = decimal.toDecimal(product.minimumStock);
      if (outOfStock) {
        return current.lessThanOrEqualTo(0);
      }
      return current.greaterThan(0) && current.lessThanOrEqualTo(min);
    });
    return {
      items: filtered.slice(skip, skip + take),
      total: filtered.length,
    };
  }

  const [items, total] = await Promise.all([
    prisma.product.findMany({
      where: filters,
      skip,
      take,
      orderBy: { name: 'asc' },
      include: productInclude,
    }),
    prisma.product.count({ where: filters }),
  ]);

  return { items, total };
}

async function findById(id) {
  return prisma.product.findUnique({
    where: { id },
    include: productInclude,
  });
}

async function findBySku(sku) {
  return prisma.product.findUnique({ where: { sku } });
}

async function create(data) {
  return prisma.product.create({
    data,
    include: productInclude,
  });
}

async function update(id, data) {
  return prisma.product.update({
    where: { id },
    data,
    include: productInclude,
  });
}

async function replaceSuppliers(productId, supplierIds) {
  await prisma.$transaction([
    prisma.productSupplier.deleteMany({ where: { productId } }),
    ...(supplierIds.length
      ? [
          prisma.productSupplier.createMany({
            data: supplierIds.map((supplierId) => ({ productId, supplierId })),
          }),
        ]
      : []),
  ]);
}

async function countPurchaseOrSaleItems(productId) {
  const [purchases, sales] = await Promise.all([
    prisma.purchaseItem.count({ where: { productId } }),
    prisma.saleItem.count({ where: { productId } }),
  ]);
  return purchases + sales;
}

async function countByCategory(categoryId) {
  return prisma.product.count({ where: { categoryId } });
}

async function softDelete(id) {
  return prisma.product.update({
    where: { id },
    data: { isActive: false },
    include: productInclude,
  });
}

module.exports = {
  findMany,
  findById,
  findBySku,
  create,
  update,
  replaceSuppliers,
  countPurchaseOrSaleItems,
  countByCategory,
  softDelete,
};
