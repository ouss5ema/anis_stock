const rateLimit = require('express-rate-limit');
const { env } = require('../config/env');

function authLimiter() {
  return rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 20,
    standardHeaders: true,
    legacyHeaders: false,
    skip: () => env.NODE_ENV === 'test',
    message: {
      success: false,
      message: 'Too many attempts. Please try again later.',
      errors: [],
    },
  });
}

module.exports = { authLimiter };
