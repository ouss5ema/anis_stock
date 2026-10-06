const productService = require('../services/product.service');
const { asyncHandler } = require('../utils/asyncHandler');
const { success, created } = require('../utils/response');

const list = asyncHandler(async (req, res) => {
  const data = await productService.listProducts(req.validated.query);
  return success(res, data);
});

const getById = asyncHandler(async (req, res) => {
  const data = await productService.getProduct(req.params.id);
  return success(res, data);
});

const create = asyncHandler(async (req, res) => {
  const data = await productService.createProduct(req.body);
  return created(res, data, 'Product created');
});

const update = asyncHandler(async (req, res) => {
  const data = await productService.updateProduct(req.params.id, req.body);
  return success(res, data, 'Product updated');
});

const remove = asyncHandler(async (req, res) => {
  const data = await productService.deleteProduct(req.params.id);
  return success(res, data, 'Product deactivated');
});

const getHistory = asyncHandler(async (req, res) => {
  const data = await productService.getProductHistory(req.params.id);
  return success(res, data);
});

module.exports = { list, getById, getHistory, create, update, remove };
