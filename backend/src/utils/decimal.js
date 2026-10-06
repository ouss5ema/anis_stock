const { Prisma } = require('@prisma/client');

function toDecimal(value) {
  return new Prisma.Decimal(value ?? 0);
}

function add(a, b) {
  return toDecimal(a).plus(toDecimal(b));
}

function subtract(a, b) {
  return toDecimal(a).minus(toDecimal(b));
}

function multiply(a, b) {
  return toDecimal(a).times(toDecimal(b));
}

function isNegative(value) {
  return toDecimal(value).isNegative();
}

function isZero(value) {
  return toDecimal(value).isZero();
}

function lessThanOrEqual(a, b) {
  return toDecimal(a).lessThanOrEqualTo(toDecimal(b));
}

function greaterThan(a, b) {
  return toDecimal(a).greaterThan(toDecimal(b));
}

function toString(value) {
  if (value === null || value === undefined) {
    return null;
  }
  return toDecimal(value).toFixed(3);
}

module.exports = {
  toDecimal,
  add,
  subtract,
  multiply,
  isNegative,
  isZero,
  lessThanOrEqual,
  greaterThan,
  toString,
};
