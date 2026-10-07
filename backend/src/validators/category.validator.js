const { z } = require('zod');
const { paginatedQuery, idParams, idWithOptionalReason, reasonSchema } = require('./common.validator');

const createCategorySchema = z.object({
  body: z.object({
    name: z.string().trim().min(2).max(80),
    description: z.string().trim().max(500).optional().nullable(),
    isActive: z.boolean().optional(),
  }),
});

const updateCategorySchema = z
  .object({
    body: z
      .object({
        name: z.string().trim().min(2).max(80).optional(),
        description: z.string().trim().max(500).optional().nullable(),
        isActive: z.boolean().optional(),
      })
      .refine((data) => Object.keys(data).length > 0, {
        message: 'At least one field is required',
      }),
  })
  .merge(idParams());

const listCategoriesSchema = paginatedQuery();
const getCategorySchema = idParams();
const deleteCategorySchema = idWithOptionalReason();

const reassignCategorySchema = z
  .object({
    body: z.object({
      targetCategoryId: z.string().uuid('Catégorie cible invalide'),
      reason: reasonSchema.optional(),
    }),
  })
  .merge(idParams());

module.exports = {
  createCategorySchema,
  updateCategorySchema,
  listCategoriesSchema,
  getCategorySchema,
  deleteCategorySchema,
  reassignCategorySchema,
};
