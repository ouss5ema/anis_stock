const { z } = require('zod');
const { paginatedQuery, idParams, decimalNonNegative } = require('./common.validator');

const productUnitEnum = z.enum(['UNIT', 'PACK', 'CARTON', 'BOX', 'RECHARGE', 'OTHER']);

const decimalString = decimalNonNegative;

const optionalSku = z
  .union([z.string(), z.null()])
  .optional()
  .transform((value) => {
    if (value === undefined) {
      return undefined;
    }
    if (value == null) {
      return null;
    }
    const normalized = value.trim().toUpperCase();
    return normalized === '' ? null : normalized;
  })
  .refine((value) => value == null || value.length <= 60, {
    message: 'SKU must be at most 60 characters',
  });

const createProductSchema = z.object({
  body: z.object({
    sku: optionalSku,
    name: z.string().trim().min(2).max(160),
    description: z.string().trim().max(1000).optional().nullable(),
    categoryId: z.string().uuid(),
    unit: productUnitEnum.optional(),
    purchasePrice: decimalString,
    salePrice: decimalString,
    minimumStock: decimalString.optional(),
    isActive: z.boolean().optional(),
    supplierIds: z.array(z.string().uuid()).optional(),
  }),
});

const updateProductSchema = z
  .object({
    body: z
      .object({
        sku: optionalSku,
        name: z.string().trim().min(2).max(160).optional(),
        description: z.string().trim().max(1000).optional().nullable(),
        categoryId: z.string().uuid().optional(),
        unit: productUnitEnum.optional(),
        purchasePrice: decimalString.optional(),
        salePrice: decimalString.optional(),
        minimumStock: decimalString.optional(),
        isActive: z.boolean().optional(),
        supplierIds: z.array(z.string().uuid()).optional(),
      })
      .refine((data) => Object.keys(data).length > 0, {
        message: 'At least one field is required',
      }),
  })
  .merge(idParams());

const listProductsSchema = paginatedQuery({
  categoryId: z.string().uuid().optional(),
  lowStock: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
  outOfStock: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => value === 'true'),
});

const getProductSchema = idParams();
const deleteProductSchema = idParams();

module.exports = {
  createProductSchema,
  updateProductSchema,
  listProductsSchema,
  getProductSchema,
  deleteProductSchema,
};
