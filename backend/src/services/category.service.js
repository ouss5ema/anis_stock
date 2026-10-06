const { ApiError } = require('../utils/ApiError');
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

async function deleteCategory(id) {
  const category = await categoryRepository.findById(id);
  if (!category) {
    throw ApiError.notFound('Category not found');
  }

  const productCount = await productRepository.countByCategory(id);
  if (productCount > 0) {
    throw ApiError.conflict('Cannot delete a category that still has products. Deactivate it instead.');
  }

  const updated = await categoryRepository.softDelete(id);
  return serializeCategory(updated);
}

module.exports = {
  listCategories,
  getCategory,
  createCategory,
  updateCategory,
  deleteCategory,
};
