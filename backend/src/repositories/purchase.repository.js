const { prisma } = require('../config/prisma');

const purchaseInclude = {
  supplier: {
    select: { id: true, name: true, type: true, phone: true },
  },
  items: {
    include: {
      product: {
        select: { id: true, sku: true, name: true, unit: true, currentStock: true },
      },
    },
    orderBy: { id: 'asc' },
  },
};

function buildWhere({ search, supplierId, status, from, to }) {
  return {
    ...(supplierId ? { supplierId } : {}),
    ...(status ? { status } : {}),
    ...(from || to
      ? {
          purchaseDate: {
            ...(from ? { gte: from } : {}),
            ...(to ? { lte: to } : {}),
          },
        }
      : {}),
    ...(search
      ? {
          OR: [
            { referenceNumber: { contains: search, mode: 'insensitive' } },
            { notes: { contains: search, mode: 'insensitive' } },
            { supplier: { name: { contains: search, mode: 'insensitive' } } },
          ],
        }
      : {}),
  };
}

async function findMany({ skip, take, search, supplierId, status, from, to }) {
  const where = buildWhere({ search, supplierId, status, from, to });
  const [items, total] = await Promise.all([
    prisma.purchase.findMany({
      where,
      skip,
      take,
      orderBy: [{ purchaseDate: 'desc' }, { createdAt: 'desc' }],
      include: {
        supplier: { select: { id: true, name: true, type: true } },
        _count: { select: { items: true } },
      },
    }),
    prisma.purchase.count({ where }),
  ]);
  return { items, total };
}

async function findById(id, client = prisma) {
  return client.purchase.findUnique({
    where: { id },
    include: purchaseInclude,
  });
}

async function findByReference(referenceNumber, client = prisma) {
  return client.purchase.findUnique({ where: { referenceNumber } });
}

module.exports = {
  purchaseInclude,
  findMany,
  findById,
  findByReference,
};
