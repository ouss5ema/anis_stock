const { z } = require('zod');
const { paginatedQuery, idParams, decimalPositive, decimalNonNegative, idWithRequiredReason } = require('./common.validator');

const documentItemSchema = z.object({
  productId: z.string().uuid(),
  quantity: decimalPositive,
  unitPrice: decimalNonNegative,
});

const listPurchasesSchema = paginatedQuery({
  supplierId: z.string().uuid().optional(),
  status: z.enum(['CONFIRMED', 'CANCELLED']).optional(),
  from: z.string().datetime({ offset: true }).or(z.string().min(8)).optional(),
  to: z.string().datetime({ offset: true }).or(z.string().min(8)).optional(),
});

const createPurchaseSchema = z.object({
  body: z.object({
    supplierId: z.string().uuid(),
    purchaseDate: z.string().optional(),
    referenceNumber: z.string().trim().min(3).max(40).optional(),
    notes: z.string().trim().max(1000).optional().nullable(),
    items: z.array(documentItemSchema).min(1, 'At least one line is required'),
  }),
});

const updatePurchaseSchema = z
  .object({
    body: z
      .object({
        supplierId: z.string().uuid().optional(),
        purchaseDate: z.string().optional(),
        referenceNumber: z.string().trim().min(3).max(40).optional(),
        notes: z.string().trim().max(1000).optional().nullable(),
        items: z.array(documentItemSchema).min(1).optional(),
      })
      .refine((data) => Object.keys(data).length > 0, {
        message: 'At least one field is required',
      }),
  })
  .merge(idParams());

const getPurchaseSchema = idParams();
/** Cancellation: the reason is mandatory (3 to 300 characters). */
const deletePurchaseSchema = idWithRequiredReason();

module.exports = {
  listPurchasesSchema,
  createPurchaseSchema,
  updatePurchaseSchema,
  getPurchaseSchema,
  deletePurchaseSchema,
};
