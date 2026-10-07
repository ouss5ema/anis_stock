const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const { ErrorCodes } = require('../utils/errorCodes');
const decimal = require('../utils/decimal');
const audit = require('./audit.service');
const stockService = require('./stock.service');
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
  const { page, pageSize, search, includeInactive, archived, categoryId, lowStock, outOfStock } = query;
  const skip = (page - 1) * pageSize;
  const { items, total } = await productRepository.findMany({
    skip,
    take: pageSize,
    search,
    includeInactive,
    archived,
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

async function updateProduct(id, payload, actor = {}) {
  const product = await productRepository.findById(id);
  if (!product) {
    throw ApiError.notFound('Product not found');
  }

  const statusChanges =
    Object.prototype.hasOwnProperty.call(payload, 'isActive') && payload.isActive !== product.isActive;
  if (statusChanges) {
    if (actor.role !== 'ADMIN') {
      throw ApiError.forbidden('Seul un administrateur peut archiver ou réactiver un produit');
    }
    return changeProductStatus(id, payload, actor);
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

function archiveData(isActive, userId) {
  return isActive
    ? { isActive: true, archivedAt: null, archivedById: null }
    : { isActive: false, archivedAt: new Date(), archivedById: userId ?? null };
}

/** `isActive` toggled from the product form (ADMIN): same as archive/restore, audited. */
async function changeProductStatus(id, payload, actor) {
  const { supplierIds, isActive, ...data } = payload;
  if (supplierIds) {
    await assertSuppliersExist(supplierIds);
    await productRepository.replaceSuppliers(id, supplierIds);
  }
  const updated = await prisma.$transaction(async (tx) => {
    const result = await productRepository.update(id, { ...data, ...archiveData(isActive, actor.id) }, tx);
    await audit.record(tx, {
      action: 'PRODUCT_STATUS_CHANGED',
      entityType: 'PRODUCT',
      entityId: id,
      entityLabel: result.name,
      userId: actor.id,
      metadata: { isActive, currentStock: decimal.toString(result.currentStock) },
    });
    return result;
  });
  return serializeProduct(updated);
}

/** Indicative only: deleteProduct decides under lock. */
async function getDeletePreview(id) {
  const product = await productRepository.findById(id);
  if (!product) {
    throw ApiError.notFound('Produit introuvable');
  }
  const history = await productRepository.countHistory(id);
  const stock = decimal.toDecimal(product.currentStock);
  return {
    productId: product.id,
    productName: product.name,
    isArchived: !product.isActive,
    mode: history.total === 0 && stock.isZero() ? 'DELETE' : 'ARCHIVE',
    currentStock: decimal.toString(stock),
    hasStock: !stock.isZero(),
    history,
  };
}

/**
 * Real deletion only when the product has no movement, no document line and
 * a zero stock. Otherwise it is archived (stock untouched, history kept).
 */
async function deleteProduct(id, userId, reason) {
  const exists = await productRepository.findById(id);
  if (!exists) {
    throw ApiError.notFound('Produit introuvable');
  }

  return prisma.$transaction(async (tx) => {
    // Same row lock as applyMovement: no movement can slip in meanwhile.
    await stockService.lockProduct(tx, id);
    const product = await productRepository.findById(id, tx);
    const history = await productRepository.countHistory(id, tx);
    const stock = decimal.toDecimal(product.currentStock);

    if (history.total === 0 && stock.isZero()) {
      await tx.product.delete({ where: { id } });
      await audit.record(tx, {
        action: 'PRODUCT_DELETED',
        entityType: 'PRODUCT',
        entityId: id,
        entityLabel: product.name,
        reason,
        userId,
        metadata: { sku: product.sku, categoryId: product.categoryId },
      });
      return { ...serializeProduct(product), deletionMode: 'DELETED' };
    }

    if (!product.isActive) {
      throw ApiError.conflict('Ce produit est déjà archivé', [], ErrorCodes.ALREADY_ARCHIVED);
    }

    const archived = await productRepository.update(id, archiveData(false, userId), tx);
    await audit.record(tx, {
      action: 'PRODUCT_ARCHIVED',
      entityType: 'PRODUCT',
      entityId: id,
      entityLabel: product.name,
      reason,
      userId,
      metadata: { currentStock: decimal.toString(stock), history },
    });
    return { ...serializeProduct(archived), deletionMode: 'ARCHIVED' };
  });
}

async function restoreProduct(id, userId, reason) {
  const product = await productRepository.findById(id);
  if (!product) {
    throw ApiError.notFound('Produit introuvable');
  }
  if (product.isActive) {
    throw ApiError.conflict('Ce produit n’est pas archivé', [], ErrorCodes.NOT_ARCHIVED);
  }

  const restored = await prisma.$transaction(async (tx) => {
    const result = await productRepository.update(id, archiveData(true), tx);
    await audit.record(tx, {
      action: 'PRODUCT_RESTORED',
      entityType: 'PRODUCT',
      entityId: id,
      entityLabel: product.name,
      reason,
      userId,
      metadata: { currentStock: decimal.toString(result.currentStock) },
    });
    return result;
  });
  return serializeProduct(restored);
}

module.exports = {
  listProducts,
  getProduct,
  getProductHistory,
  createProduct,
  updateProduct,
  deleteProduct,
  restoreProduct,
  getDeletePreview,
};
