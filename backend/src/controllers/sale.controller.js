const saleService = require('../services/sale.service');
const { asyncHandler } = require('../utils/asyncHandler');
const { success, created } = require('../utils/response');

const list = asyncHandler(async (req, res) => {
  const data = await saleService.listSales(req.validated.query);
  return success(res, data);
});

const getById = asyncHandler(async (req, res) => {
  const data = await saleService.getSale(req.params.id);
  return success(res, data);
});

const listItems = asyncHandler(async (req, res) => {
  const data = await saleService.listSaleItems(req.params.id);
  return success(res, data);
});

const create = asyncHandler(async (req, res) => {
  const data = await saleService.createSale(req.body, req.user.id);
  return created(res, data, 'Sale created');
});

const update = asyncHandler(async (req, res) => {
  const data = await saleService.updateSale(req.params.id, req.body, req.user.id);
  return success(res, data, 'Sale updated');
});

const remove = asyncHandler(async (req, res) => {
  const data = await saleService.cancelSale(req.params.id, req.user.id, req.body?.reason);
  return success(res, data, 'Sale cancelled');
});

module.exports = { list, getById, listItems, create, update, remove };
