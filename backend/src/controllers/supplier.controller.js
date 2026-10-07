const supplierService = require('../services/supplier.service');
const { asyncHandler } = require('../utils/asyncHandler');
const { success, created } = require('../utils/response');

const list = asyncHandler(async (req, res) => {
  const data = await supplierService.listSuppliers(req.validated.query);
  return success(res, data);
});

const getById = asyncHandler(async (req, res) => {
  const data = await supplierService.getSupplier(req.params.id);
  return success(res, data);
});

const create = asyncHandler(async (req, res) => {
  const data = await supplierService.createSupplier(req.body);
  return created(res, data, 'Supplier created');
});

const update = asyncHandler(async (req, res) => {
  const data = await supplierService.updateSupplier(req.params.id, req.body);
  return success(res, data, 'Supplier updated');
});

const remove = asyncHandler(async (req, res) => {
  const data = await supplierService.deleteSupplier(req.params.id, req.user.id, req.body?.reason);
  return success(res, data, 'Supplier deactivated');
});

module.exports = { list, getById, create, update, remove };
