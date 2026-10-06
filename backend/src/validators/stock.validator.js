const { z } = require('zod');
const { paginatedQuery, decimalPositive } = require('./common.validator');

const listMovementsSchema = paginatedQuery({
  productId: z.string().uuid().optional(),
  type: z
    .enum([
      'PURCHASE',
      'SALE',
      'ADJUSTMENT_IN',
      'ADJUSTMENT_OUT',
      'RETURN_PURCHASE',
      'RETURN_SALE',
    ])
    .optional(),
  from: z.string().optional(),
  to: z.string().optional(),
});

const adjustStockSchema = z.object({
  body: z.object({
    productId: z.string().uuid(),
    direction: z.enum(['in', 'out']),
    quantity: decimalPositive,
    reason: z.string().trim().min(3).max(300),
  }),
});

module.exports = { listMovementsSchema, adjustStockSchema };
