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

const reasonSchema = z
  .string({ required_error: 'Le motif est obligatoire', invalid_type_error: 'Le motif est obligatoire' })
  .trim()
  .min(3, 'Le motif doit contenir au moins 3 caractères')
  .max(300, 'Le motif ne peut pas dépasser 300 caractères');

/** `:id` + body `{ reason }` (3 to 300 characters), mandatory. */
function idWithRequiredReason() {
  return z
    .object({
      body: z.object({ reason: reasonSchema }, { required_error: 'Le motif est obligatoire' }),
    })
    .merge(idParams());
}

/** `:id` + optional body `{ reason }`. */
function idWithOptionalReason() {
  return z
    .object({
      body: z
        .object({ reason: reasonSchema.optional() })
        .optional()
        .transform((body) => body ?? {}),
    })
    .merge(idParams());
}

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
  reasonSchema,
  idWithRequiredReason,
  idWithOptionalReason,
};
