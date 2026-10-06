const { prisma } = require('../config/prisma');

function buildWhere({ search, includeInactive }) {
  const where = {};

  if (!includeInactive) {
    where.isActive = true;
  }

  if (search) {
    where.OR = [
      { name: { contains: search, mode: 'insensitive' } },
      { description: { contains: search, mode: 'insensitive' } },
    ];
  }

  return where;
}

async function findMany({ skip, take, search, includeInactive }) {
  const where = buildWhere({ search, includeInactive });

  const [items, total] = await Promise.all([
    prisma.category.findMany({
      where,
      skip,
      take,
      orderBy: { name: 'asc' },
      include: { _count: { select: { products: true } } },
    }),
    prisma.category.count({ where }),
  ]);

  return { items, total };
}

async function findById(id) {
  return prisma.category.findUnique({
    where: { id },
    include: { _count: { select: { products: true } } },
  });
}

async function findByName(name) {
  return prisma.category.findUnique({ where: { name } });
}

async function create(data) {
  return prisma.category.create({
    data,
    include: { _count: { select: { products: true } } },
  });
}

async function update(id, data) {
  return prisma.category.update({
    where: { id },
    data,
    include: { _count: { select: { products: true } } },
  });
}

async function softDelete(id) {
  return prisma.category.update({
    where: { id },
    data: { isActive: false },
    include: { _count: { select: { products: true } } },
  });
}

module.exports = {
  findMany,
  findById,
  findByName,
  create,
  update,
  softDelete,
};
