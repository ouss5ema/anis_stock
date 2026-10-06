const stockQueryService = require('../services/stock-query.service');
const { asyncHandler } = require('../utils/asyncHandler');
const { success } = require('../utils/response');

const listMovements = asyncHandler(async (req, res) => {
  const data = await stockQueryService.listMovements(req.validated.query);
  return success(res, data);
});

const adjust = asyncHandler(async (req, res) => {
  const data = await stockQueryService.adjustStock(req.body, req.user.id);
  return success(res, data, 'Stock adjusted');
});

module.exports = { listMovements, adjust };
