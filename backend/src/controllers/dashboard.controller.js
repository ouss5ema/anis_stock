const dashboardService = require('../services/dashboard.service');
const { asyncHandler } = require('../utils/asyncHandler');
const { success } = require('../utils/response');

const get = asyncHandler(async (req, res) => {
  const period = req.validated?.query?.period || req.query.period || 'today';
  const data = await dashboardService.getDashboard(period);
  return success(res, data);
});

module.exports = { get };
