/**
 * Stable machine-readable error codes, sent as `code` next to
 * `{ success: false, message, errors }`. Never rename a value: clients rely on them.
 */
const ErrorCodes = Object.freeze({
  FORBIDDEN: 'FORBIDDEN',
  INSUFFICIENT_STOCK: 'INSUFFICIENT_STOCK',
  ALREADY_CANCELLED: 'ALREADY_CANCELLED',
  DOCUMENT_CANCELLED: 'DOCUMENT_CANCELLED',
  ALREADY_ARCHIVED: 'ALREADY_ARCHIVED',
  NOT_ARCHIVED: 'NOT_ARCHIVED',
  CATEGORY_NOT_EMPTY: 'CATEGORY_NOT_EMPTY',
  INVALID_TARGET_CATEGORY: 'INVALID_TARGET_CATEGORY',
});

module.exports = { ErrorCodes };
