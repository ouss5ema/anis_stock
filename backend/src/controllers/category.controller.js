const categoryService = require('../services/category.service');
const { asyncHandler } = require('../utils/asyncHandler');
const { success, created } = require('../utils/response');

const list = asyncHandler(async (req, res) => {
  const data = await categoryService.listCategories(req.validated.query);
  return success(res, data);
});

const getById = asyncHandler(async (req, res) => {
  const data = await categoryService.getCategory(req.params.id);
  return success(res, data);
});

const create = asyncHandler(async (req, res) => {
  const data = await categoryService.createCategory(req.body);
  return created(res, data, 'Category created');
});

const update = asyncHandler(async (req, res) => {
  const data = await categoryService.updateCategory(req.params.id, req.body);
  return success(res, data, 'Category updated');
});

const remove = asyncHandler(async (req, res) => {
  const data = await categoryService.deleteCategory(req.params.id, req.user.id, req.body?.reason);
  return success(res, data, 'Catégorie supprimée');
});

const reassign = asyncHandler(async (req, res) => {
  const data = await categoryService.reassignProducts(
    req.params.id,
    req.body.targetCategoryId,
    req.user.id,
    req.body.reason
  );
  return success(res, data, 'Produits réaffectés');
});

module.exports = { list, getById, create, update, remove, reassign };
