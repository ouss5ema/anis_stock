const { z } = require('zod');
const { paginatedQuery, idParams } = require('./common.validator');

const supplierTypeEnum = z.enum(['TABAC', 'TELECOM', 'OTHER']);

const createSupplierSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2).max(160),
    type: supplierTypeEnum.optional(),
    phone: z.string().trim().max(40).optional().nullable(),
    email: z
      .union([z.string().trim().email().toLowerCase(), z.literal(''), z.null()])
      .optional()
      .transform((value) => (value === '' ? null : value)),
    address: z.string().trim().max(300).optional().nullable(),
    taxNumber: z.string().trim().max(60).optional().nullable(),
    notes: z.string().trim().max(1000).optional().nullable(),
    isActive: z.boolean().optional(),
    productIds: z.array(z.string().uuid()).optional(),
  }),
});

const updateSupplierSchema = z
  .object({
    body: z
      .object({
        name: z.string().trim().min(2).max(160).optional(),
        type: supplierTypeEnum.optional(),
        phone: z.string().trim().max(40).optional().nullable(),
        email: z
          .union([z.string().trim().email().toLowerCase(), z.literal(''), z.null()])
          .optional()
          .transform((value) => (value === '' ? null : value)),
        address: z.string().trim().max(300).optional().nullable(),
        taxNumber: z.string().trim().max(60).optional().nullable(),
        notes: z.string().trim().max(1000).optional().nullable(),
        isActive: z.boolean().optional(),
        productIds: z.array(z.string().uuid()).optional(),
      })
      .refine((data) => Object.keys(data).length > 0, {
        message: 'At least one field is required',
      }),
  })
  .merge(idParams());

const listSuppliersSchema = paginatedQuery({
  type: supplierTypeEnum.optional(),
});

const getSupplierSchema = idParams();
const deleteSupplierSchema = idParams();

module.exports = {
  createSupplierSchema,
  updateSupplierSchema,
  listSuppliersSchema,
  getSupplierSchema,
  deleteSupplierSchema,
};
