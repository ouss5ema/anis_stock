const { Prisma } = require('@prisma/client');
const { prisma } = require('../config/prisma');
const { ApiError } = require('../utils/ApiError');
const { ErrorCodes } = require('../utils/errorCodes');
const audit = require('./audit.service');
const { serializeCategory } = require('../utils/serialize');
const { paginationMeta } = require('../utils/pagination');
const categoryRepository = require('../repositories/category.repository');
const productRepository = require('../repositories/product.repository');

async function listCategories(query) {
  const { page, pageSize, search, includeInactive } = query;
  const skip = (page - 1) * pageSize;
  const { items, total } = await categoryRepository.findMany({
    skip,
    take: pageSize,
    search,
    includeInactive,
  });

  return {
    items: items.map(serializeCategory),
    pagination: paginationMeta(total, page, pageSize),
  };
}

async function getCategory(id) {
  const category = await categoryRepository.findById(id);
  if (!category) {
    throw ApiError.notFound('Category not found');
  }
  return serializeCategory(category);
}

async function createCategory(payload) {
  const existing = await categoryRepository.findByName(payload.name);
  if (existing) {
    throw ApiError.conflict('A category with this name already exists');
  }

  const category = await categoryRepository.create(payload);
  return serializeCategory(category);
}

async function updateCategory(id, payload) {
  const category = await categoryRepository.findById(id);
  if (!category) {
    throw ApiError.notFound('Category not found');
  }

  if (payload.name && payload.name !== category.name) {
    const existing = await categoryRepository.findByName(payload.name);
    if (existing) {
      throw ApiError.conflict('A category with this name already exists');
    }
  }

  const updated = await categoryRepository.update(id, payload);
  return serializeCategory(updated);
}

function notEmptyError(category, productCount) {
  return ApiError.conflict(
    `La catégorie « ${category.name} » contient ${productCount} produit(s), archivés compris. ` +
      'Réaffectez-les à une autre catégorie avant de la supprimer.',
    [{ field: 'productCount', message: 'Catégorie non vide', productCount }],
    ErrorCodes.CATEGORY_NOT_EMPTY
  );
}

/** Real deletion, only when no product (archived included) uses the category. */
async function deleteCategory(id, userId, reason) {
  const category = await categoryRepository.findById(id);
  if (!category) {
    throw ApiError.notFound('Catégorie introuvable');
  }

  return prisma.$transaction(async (tx) => {
    await tx.$queryRaw`SELECT id FROM categories WHERE id = ${id} FOR UPDATE`;
    const productCount = await tx.product.count({ where: { categoryId: id } });
    if (productCount > 0) {
      throw notEmptyError(category, productCount);
    }
    try {
      await tx.category.delete({ where: { id } });
    } catch (error) {
      // A product created meanwhile: the foreign key protects the data.
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2003') {
        throw notEmptyError(category, await productRepository.countByCategory(id));
      }
      throw error;
    }
    await audit.record(tx, {
      action: 'CATEGORY_DELETED',
      entityType: 'CATEGORY',
      entityId: id,
      entityLabel: category.name,
      reason,
      userId,
      metadata: { description: category.description },
    });
    return { ...serializeCategory(category), deletionMode: 'DELETED' };
  });
}

/** Moves every product (archived included) to another active category. */
async function reassignProducts(id, targetCategoryId, userId, reason) {
  const source = await categoryRepository.findById(id);
  if (!source) {
    throw ApiError.notFound('Catégorie introuvable');
  }
  if (targetCategoryId === id) {
    throw ApiError.badRequest(
      'La catégorie cible doit être différente de la catégorie source',
      [],
      ErrorCodes.INVALID_TARGET_CATEGORY
    );
  }
  const target = await categoryRepository.findById(targetCategoryId);
  if (!target || !target.isActive) {
    throw ApiError.badRequest(
      'La catégorie cible est introuvable ou inactive',
      [],
      ErrorCodes.INVALID_TARGET_CATEGORY
    );
  }

  return prisma.$transaction(async (tx) => {
    const products = await tx.product.findMany({
      where: { categoryId: id },
      select: { id: true, name: true },
    });
    const result = await tx.product.updateMany({
      where: { categoryId: id },
      data: { categoryId: targetCategoryId },
    });
    await audit.record(tx, {
      action: 'CATEGORY_PRODUCTS_REASSIGNED',
      entityType: 'CATEGORY',
      entityId: id,
      entityLabel: source.name,
      reason,
      userId,
      metadata: {
        from: { id: source.id, name: source.name },
        to: { id: target.id, name: target.name },
        movedCount: result.count,
        products: products.map((product) => product.name),
      },
    });
    return {
      movedCount: result.count,
      sourceCategory: serializeCategory(source),
      targetCategory: serializeCategory(target),
    };
  });
}

module.exports = {
  listCategories,
  getCategory,
  createCategory,
  updateCategory,
  deleteCategory,
  reassignProducts,
};
