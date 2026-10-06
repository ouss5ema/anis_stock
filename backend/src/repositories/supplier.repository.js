const { prisma } = require('../config/prisma');

const supplierInclude = {
  products: {
    include: {
      product: {
        select: { id: true, sku: true, name: true },
      },
    },
  },
};

function buildWhere({ search, includeInactive, type }) {
  return {
    ...(includeInactive ? {} : { isActive: true }),
    ...(type ? { type } : {}),
    ...(search
      ? {
          OR: [
            { name: { contains: search, mode: 'insensitive' } },
            { phone: { contains: search, mode: 'insensitive' } },
            { email: { contains: search, mode: 'insensitive' } },
          ],
        }
      : {}),
  };
}

async function findMany({ skip, take, search, includeInactive, type }) {
  const where = buildWhere({ search, includeInactive, type });

  const [items, total] = await Promise.all([
    prisma.supplier.findMany({
      where,
      skip,
      take,
      orderBy: { name: 'asc' },
      include: supplierInclude,
    }),
    prisma.supplier.count({ where }),
  ]);

  return { items, total };
}

async function findById(id) {
  return prisma.supplier.findUnique({
    where: { id },
    include: supplierInclude,
  });
}

async function findByIds(ids) {
  if (!ids?.length) {
    return [];
  }
  return prisma.supplier.findMany({
    where: { id: { in: ids } },
  });
}

async function create(data) {
  return prisma.supplier.create({
    data,
    include: supplierInclude,
  });
}

async function update(id, data) {
  return prisma.supplier.update({
    where: { id },
    data,
    include: supplierInclude,
  });
}

async function replaceProducts(supplierId, productIds) {
  await prisma.$transaction([
    prisma.productSupplier.deleteMany({ where: { supplierId } }),
    ...(productIds.length
      ? [
          prisma.productSupplier.createMany({
            data: productIds.map((productId) => ({ productId, supplierId })),
          }),
        ]
      : []),
  ]);
}

async function countPurchases(supplierId) {
  return prisma.purchase.count({ where: { supplierId } });
}

async function softDelete(id) {
  return prisma.supplier.update({
    where: { id },
    data: { isActive: false },
    include: supplierInclude,
  });
}

module.exports = {
  findMany,
  findById,
  findByIds,
  create,
  update,
  replaceProducts,
  countPurchases,
  softDelete,
};
