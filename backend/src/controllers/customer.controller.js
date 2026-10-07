const customerService = require('../services/customer.service');
const { asyncHandler } = require('../utils/asyncHandler');
const { success, created } = require('../utils/response');

const list = asyncHandler(async (req, res) => {
  const data = await customerService.listCustomers(req.validated.query);
  return success(res, data);
});

const getById = asyncHandler(async (req, res) => {
  const data = await customerService.getCustomer(req.params.id);
  return success(res, data);
});

const create = asyncHandler(async (req, res) => {
  const data = await customerService.createCustomer(req.body);
  return created(res, data, 'Customer created');
});

const update = asyncHandler(async (req, res) => {
  const data = await customerService.updateCustomer(req.params.id, req.body);
  return success(res, data, 'Customer updated');
});

const remove = asyncHandler(async (req, res) => {
  const data = await customerService.deleteCustomer(req.params.id, req.user.id, req.body?.reason);
  return success(res, data, 'Customer deactivated');
});

module.exports = { list, getById, create, update, remove };
