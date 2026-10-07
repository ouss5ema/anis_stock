const decimal = require('./decimal');

/** `'8.000'` -> `'8'`, `'2.500'` -> `'2,5'` (for French business messages). */
function quantityFr(value) {
  return decimal.toDecimal(value).toString().replace('.', ',');
}

module.exports = { quantityFr };
