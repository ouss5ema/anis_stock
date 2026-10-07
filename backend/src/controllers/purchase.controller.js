const purchaseService = require('../services/purchase.service');
const { asyncHandler } = require('../utils/asyncHandler');
const { success, created } = require('../utils/response');

const list = asyncHandler(async (req, res) => {
  const data = await purchaseService.listPurchases(req.validated.query);
  return success(res, data);
});

const getById = asyncHandler(async (req, res) => {
  const data = await purchaseService.getPurchase(req.params.id);
  return success(res, data);
});

const listItems = asyncHandler(async (req, res) => {
  const data = await purchaseService.listPurchaseItems(req.params.id);
  return success(res, data);
});

const create = asyncHandler(async (req, res) => {
  const data = await purchaseService.createPurchase(req.body, req.user.id);
  return created(res, data, 'Purchase created');
});

const update = asyncHandler(async (req, res) => {
  const data = await purchaseService.updatePurchase(req.params.id, req.body, req.user.id);
  return success(res, data, 'Purchase updated');
});

const remove = asyncHandler(async (req, res) => {
  const data = await purchaseService.cancelPurchase(req.params.id, req.user.id, req.body?.reason);
  return success(res, data, 'Achat annulé');
});

const cancelPreview = asyncHandler(async (req, res) => {
  const data = await purchaseService.getCancelPreview(req.params.id);
  return success(res, data);
});

module.exports = { list, getById, listItems, create, update, remove, cancelPreview };
