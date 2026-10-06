const { z } = require('zod');
const { paginatedQuery, idParams } = require('./common.validator');

const customerTypeEnum = z.enum(['FREESHOP', 'SUPERMARKET', 'SHOP', 'OTHER']);

const createCustomerSchema = z.object({
  body: z.object({
    name: z.string().trim().min(2).max(160),
    type: customerTypeEnum.optional(),
    phone: z.string().trim().max(40).optional().nullable(),
    email: z
      .union([z.string().trim().email().toLowerCase(), z.literal(''), z.null()])
      .optional()
      .transform((value) => (value === '' ? null : value)),
    address: z.string().trim().max(300).optional().nullable(),
    notes: z.string().trim().max(1000).optional().nullable(),
    isActive: z.boolean().optional(),
  }),
});

const updateCustomerSchema = z
  .object({
    body: z
      .object({
        name: z.string().trim().min(2).max(160).optional(),
        type: customerTypeEnum.optional(),
        phone: z.string().trim().max(40).optional().nullable(),
        email: z
          .union([z.string().trim().email().toLowerCase(), z.literal(''), z.null()])
          .optional()
          .transform((value) => (value === '' ? null : value)),
        address: z.string().trim().max(300).optional().nullable(),
        notes: z.string().trim().max(1000).optional().nullable(),
        isActive: z.boolean().optional(),
      })
      .refine((data) => Object.keys(data).length > 0, {
        message: 'At least one field is required',
      }),
  })
  .merge(idParams());

const listCustomersSchema = paginatedQuery({
  type: customerTypeEnum.optional(),
});

const getCustomerSchema = idParams();
const deleteCustomerSchema = idParams();

module.exports = {
  createCustomerSchema,
  updateCustomerSchema,
  listCustomersSchema,
  getCustomerSchema,
  deleteCustomerSchema,
};
