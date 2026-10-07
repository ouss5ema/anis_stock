const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const { serializeProduct, serializePurchase, serializeSale, serializeStockMovement } = require('../utils/serialize');
const { paginationMeta } = require('../utils/pagination');
const productRepository = require('../repositories/product.repository');
const categoryRepository = require('../repositories/category.repository');
const supplierRepository = require('../repositories/supplier.repository');

async function assertCategoryExists(categoryId) {
  const category = await categoryRepository.findById(categoryId);
  if (!category || !category.isActive) {
    throw ApiError.badRequest('Category not found or inactive');
  }
}

async function assertSuppliersExist(supplierIds = []) {
  if (!supplierIds.length) {
    return;
  }

  const suppliers = await supplierRepository.findByIds(supplierIds);
  if (suppliers.length !== supplierIds.length) {
    throw ApiError.badRequest('One or more suppliers were not found');
  }
}

async function listProducts(query) {
  const { page, pageSize, search, includeInactive, categoryId, lowStock, outOfStock } = query;
  const skip = (page - 1) * pageSize;
  const { items, total } = await productRepository.findMany({
    skip,
    take: pageSize,
    search,
    includeInactive,
    categoryId,
    lowStock,
    outOfStock,
  });

  return {
    items: items.map(serializeProduct),
    pagination: paginationMeta(total, page, pageSize),
  };
}

async function getProductHistory(id) {
  const product = await productRepository.findById(id);
  if (!product) {
    throw ApiError.notFound('Product not found');
  }

  const [purchaseItems, saleItems, movements] = await Promise.all([
    prisma.purchaseItem.findMany({
      where: { productId: id, purchase: { status: 'CONFIRMED' } },
      orderBy: { purchase: { purchaseDate: 'desc' } },
      take: 10,
      include: {
        purchase: {
          include: {
            supplier: { select: { id: true, name: true, type: true } },
            _count: { select: { items: true } },
          },
        },
      },
    }),
    prisma.saleItem.findMany({
      where: { productId: id, sale: { status: 'CONFIRMED' } },
      orderBy: { sale: { saleDate: 'desc' } },
      take: 10,
      include: {
        sale: {
          include: {
            customer: { select: { id: true, name: true, type: true } },
            _count: { select: { items: true } },
          },
        },
      },
    }),
    prisma.stockMovement.findMany({
      where: { productId: id },
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: {
        product: { select: { id: true, sku: true, name: true, unit: true } },
      },
    }),
  ]);

  return {
    product: serializeProduct(product),
    purchases: purchaseItems.map((item) => serializePurchase(item.purchase)),
    sales: saleItems.map((item) => serializeSale(item.sale)),
    movements: movements.map(serializeStockMovement),
  };
}

async function getProduct(id) {
  const product = await productRepository.findById(id);
  if (!product) {
    throw ApiError.notFound('Product not found');
  }
  return serializeProduct(product);
}

async function createProduct(payload) {
  await assertCategoryExists(payload.categoryId);
  await assertSuppliersExist(payload.supplierIds);

  const sku = payload.sku && String(payload.sku).trim() ? String(payload.sku).trim().toUpperCase() : null;
  if (sku) {
    const existingSku = await productRepository.findBySku(sku);
    if (existingSku) {
      throw ApiError.conflict('A product with this SKU already exists');
    }
  }

  const { supplierIds, ...data } = payload;

  const product = await productRepository.create({
    ...data,
    sku,
    currentStock: 0,
    suppliers: supplierIds?.length
      ? {
          create: supplierIds.map((supplierId) => ({ supplierId })),
        }
      : undefined,
  });

  return serializeProduct(product);
}

async function updateProduct(id, payload) {
  const product = await productRepository.findById(id);
  if (!product) {
    throw ApiError.notFound('Product not found');
  }

  if (payload.categoryId) {
    await assertCategoryExists(payload.categoryId);
  }

  if (Object.prototype.hasOwnProperty.call(payload, 'sku')) {
    const sku = payload.sku && String(payload.sku).trim() ? String(payload.sku).trim().toUpperCase() : null;
    payload.sku = sku;
    if (sku && sku !== product.sku) {
      const existingSku = await productRepository.findBySku(sku);
      if (existingSku) {
        throw ApiError.conflict('A product with this SKU already exists');
      }
    }
  }

  const { supplierIds, ...data } = payload;

  if (supplierIds) {
    await assertSuppliersExist(supplierIds);
    await productRepository.replaceSuppliers(id, supplierIds);
  }

  const updated = await productRepository.update(id, data);
  return serializeProduct(updated);
}

async function deleteProduct(id) {
  const product = await productRepository.findById(id);
  if (!product) {
    throw ApiError.notFound('Product not found');
  }

  const updated = await productRepository.softDelete(id);
  return serializeProduct(updated);
}

module.exports = {
  listProducts,
  getProduct,
  getProductHistory,
  createProduct,
  updateProduct,
  deleteProduct,
};
