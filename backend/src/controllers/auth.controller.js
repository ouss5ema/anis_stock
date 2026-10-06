const authService = require('../services/auth.service');
const { asyncHandler } = require('../utils/asyncHandler');
const { success, created } = require('../utils/response');

const register = asyncHandler(async (req, res) => {
  const result = await authService.register(req.body);
  return created(res, result, 'Account created');
});

const login = asyncHandler(async (req, res) => {
  const result = await authService.login(req.body);
  return success(res, result, 'Login successful');
});

const me = asyncHandler(async (req, res) => {
  const user = await authService.getMe(req.user.id);
  return success(res, user);
});

module.exports = { register, login, me };
