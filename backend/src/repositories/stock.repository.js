const { prisma } = require('../config/prisma');

const movementInclude = {
  product: {
    select: { id: true, sku: true, name: true, unit: true },
  },
  createdBy: {
    select: { id: true, name: true },
  },
};

function buildWhere({ productId, type, types, from, to }) {
  const typeFilter = types?.length ? { type: { in: types } } : type ? { type } : {};
  return {
    ...(productId ? { productId } : {}),
    ...typeFilter,
    ...(from || to
      ? {
          createdAt: {
            ...(from ? { gte: from } : {}),
            ...(to ? { lte: to } : {}),
          },
        }
      : {}),
  };
}

async function findMany({ skip, take, productId, type, types, from, to }) {
  const where = buildWhere({ productId, type, types, from, to });
  const [items, total] = await Promise.all([
    prisma.stockMovement.findMany({
      where,
      skip,
      take,
      orderBy: { createdAt: 'desc' },
      include: movementInclude,
    }),
    prisma.stockMovement.count({ where }),
  ]);
  return { items, total };
}

module.exports = { findMany };
