const { z } = require('zod');

const paginationQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().trim().optional(),
  includeInactive: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
});

const idParamSchema = z.object({
  id: z.string().uuid('Invalid identifier'),
});

const decimalNonNegative = z
  .union([z.string(), z.number()])
  .transform((value) => String(value))
  .refine((value) => !Number.isNaN(Number(value)) && Number(value) >= 0, {
    message: 'Must be a number greater than or equal to 0',
  });

const decimalPositive = z
  .union([z.string(), z.number()])
  .transform((value) => String(value))
  .refine((value) => !Number.isNaN(Number(value)) && Number(value) > 0, {
    message: 'Must be a number greater than 0',
  });

function paginatedQuery(extra = {}) {
  return z.object({
    query: paginationQuerySchema.extend(extra),
  });
}

function idParams() {
  return z.object({
    params: idParamSchema,
  });
}

module.exports = {
  paginationQuerySchema,
  idParamSchema,
  decimalNonNegative,
  decimalPositive,
  paginatedQuery,
  idParams,
};
