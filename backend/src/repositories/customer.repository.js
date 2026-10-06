const { prisma } = require('../config/prisma');

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
    prisma.customer.findMany({
      where,
      skip,
      take,
      orderBy: { name: 'asc' },
    }),
    prisma.customer.count({ where }),
  ]);

  return { items, total };
}

async function findById(id) {
  return prisma.customer.findUnique({ where: { id } });
}

async function create(data) {
  return prisma.customer.create({ data });
}

async function update(id, data) {
  return prisma.customer.update({
    where: { id },
    data,
  });
}

async function countSales(customerId) {
  return prisma.sale.count({ where: { customerId } });
}

async function softDelete(id) {
  return prisma.customer.update({
    where: { id },
    data: { isActive: false },
  });
}

module.exports = {
  findMany,
  findById,
  create,
  update,
  countSales,
  softDelete,
};
