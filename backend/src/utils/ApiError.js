const { ErrorCodes } = require('./errorCodes');

class ApiError extends Error {
  /**
   * @param {number} statusCode
   * @param {string} message
   * @param {Array} errors
   * @param {string} [code] stable code from ErrorCodes (optional, additive)
   */
  constructor(statusCode, message, errors = [], code = undefined) {
    super(message);
    this.name = 'ApiError';
    this.statusCode = statusCode;
    this.errors = errors;
    this.code = code;
  }

  static badRequest(message, errors = [], code = undefined) {
    return new ApiError(400, message, errors, code);
  }

  static unauthorized(message = 'Authentication required') {
    return new ApiError(401, message);
  }

  static forbidden(message = 'Access denied') {
    return new ApiError(403, message, [], ErrorCodes.FORBIDDEN);
  }

  static notFound(message = 'Resource not found') {
    return new ApiError(404, message);
  }

  static conflict(message, errors = [], code = undefined) {
    return new ApiError(409, message, errors, code);
  }

  static unprocessable(message = 'Validation failed', errors = []) {
    return new ApiError(422, message, errors);
  }

  static serviceUnavailable(message = 'Service unavailable') {
    return new ApiError(503, message);
  }
}

module.exports = { ApiError };
