const { ZodError } = require('zod');
const { Prisma } = require('@prisma/client');
const { env } = require('../config/env');
const { ApiError } = require('../utils/ApiError');
const { logger } = require('../utils/logger');

function errorHandler(err, req, res, _next) {
  if (err instanceof ZodError) {
    const errors = err.issues.map((issue) => ({
      field: issue.path.filter((part) => part !== 'body' && part !== 'params' && part !== 'query').join('.') || issue.path.join('.'),
      message: issue.message,
    }));

    return res.status(422).json({
      success: false,
      message: 'Validation failed',
      errors,
    });
  }

  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
      errors: err.errors,
    });
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2002') {
      const target = Array.isArray(err.meta?.target) ? err.meta.target.join(', ') : 'field';
      return res.status(409).json({
        success: false,
        message: `A record with this ${target} already exists`,
        errors: [],
      });
    }

    if (err.code === 'P2025') {
      return res.status(404).json({
        success: false,
        message: 'Resource not found',
        errors: [],
      });
    }

    if (err.code === 'P2003') {
      return res.status(400).json({
        success: false,
        message: 'Related record not found',
        errors: [],
      });
    }
  }

  const statusCode = err.statusCode || 500;
  const isProduction = env.NODE_ENV === 'production';

  logger.error('Unhandled error', {
    method: req.method,
    path: req.originalUrl,
    statusCode,
    code: err.code,
    message: err.message,
  });

  return res.status(statusCode).json({
    success: false,
    message: isProduction ? 'Internal server error' : err.message || 'Internal server error',
    errors: [],
  });
}

module.exports = { errorHandler };
