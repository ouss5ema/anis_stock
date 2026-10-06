const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const { serializeCustomer } = require('../utils/serialize');
const { paginationMeta } = require('../utils/pagination');
const decimal = require('../utils/decimal');
const customerRepository = require('../repositories/customer.repository');

function normalizeEmail(email) {
  if (email === '' || email === undefined) {
    return null;
  }
  return email;
}

async function listCustomers(query) {
  const { page, pageSize, search, includeInactive, type } = query;
  const skip = (page - 1) * pageSize;
  const { items, total } = await customerRepository.findMany({
    skip,
    take: pageSize,
    search,
    includeInactive,
    type,
  });

  return {
    items: items.map(serializeCustomer),
    pagination: paginationMeta(total, page, pageSize),
  };
}

async function getCustomerStats(id) {
  const confirmed = { customerId: id, status: 'CONFIRMED' };
  const [saleCount, agg, lastSale] = await Promise.all([
    prisma.sale.count({ where: confirmed }),
    prisma.sale.aggregate({
      where: confirmed,
      _sum: { totalAmount: true },
    }),
    prisma.sale.findFirst({
      where: confirmed,
      orderBy: { saleDate: 'desc' },
      select: {
        id: true,
        saleDate: true,
        referenceNumber: true,
        totalAmount: true,
      },
    }),
  ]);

  return {
    saleCount,
    totalSold: decimal.toString(agg._sum.totalAmount || 0),
    lastSale: lastSale
      ? {
          id: lastSale.id,
          date: lastSale.saleDate,
          referenceNumber: lastSale.referenceNumber,
          totalAmount: decimal.toString(lastSale.totalAmount),
        }
      : null,
  };
}

async function getCustomer(id) {
  const customer = await customerRepository.findById(id);
  if (!customer) {
    throw ApiError.notFound('Customer not found');
  }
  return serializeCustomer({
    ...customer,
    stats: await getCustomerStats(id),
  });
}

async function createCustomer(payload) {
  const customer = await customerRepository.create({
    ...payload,
    email: normalizeEmail(payload.email),
  });
  return serializeCustomer(customer);
}

async function updateCustomer(id, payload) {
  const customer = await customerRepository.findById(id);
  if (!customer) {
    throw ApiError.notFound('Customer not found');
  }

  const data = { ...payload };
  if (Object.prototype.hasOwnProperty.call(data, 'email')) {
    data.email = normalizeEmail(data.email);
  }

  const updated = await customerRepository.update(id, data);
  return serializeCustomer(updated);
}

async function deleteCustomer(id) {
  const customer = await customerRepository.findById(id);
  if (!customer) {
    throw ApiError.notFound('Customer not found');
  }

  const updated = await customerRepository.softDelete(id);
  return serializeCustomer(updated);
}

module.exports = {
  listCustomers,
  getCustomer,
  createCustomer,
  updateCustomer,
  deleteCustomer,
};
