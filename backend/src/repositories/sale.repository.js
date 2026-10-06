const { prisma } = require('../config/prisma');

const saleInclude = {
  customer: {
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

function buildWhere({ search, customerId, status, from, to }) {
  return {
    ...(customerId ? { customerId } : {}),
    ...(status ? { status } : {}),
    ...(from || to
      ? {
          saleDate: {
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
            { customer: { name: { contains: search, mode: 'insensitive' } } },
          ],
        }
      : {}),
  };
}

async function findMany({ skip, take, search, customerId, status, from, to }) {
  const where = buildWhere({ search, customerId, status, from, to });
  const [items, total] = await Promise.all([
    prisma.sale.findMany({
      where,
      skip,
      take,
      orderBy: [{ saleDate: 'desc' }, { createdAt: 'desc' }],
      include: {
        customer: { select: { id: true, name: true, type: true } },
        _count: { select: { items: true } },
      },
    }),
    prisma.sale.count({ where }),
  ]);
  return { items, total };
}

async function findById(id, client = prisma) {
  return client.sale.findUnique({
    where: { id },
    include: saleInclude,
  });
}

async function findByReference(referenceNumber, client = prisma) {
  return client.sale.findUnique({ where: { referenceNumber } });
}

module.exports = {
  saleInclude,
  findMany,
  findById,
  findByReference,
};
