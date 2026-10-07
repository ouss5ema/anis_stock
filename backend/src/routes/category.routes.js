const { Router } = require('express');
const categoryController = require('../controllers/category.controller');
const { validate } = require('../middlewares/validate.middleware');
const { requireRole } = require('../middlewares/auth.middleware');

const adminOnly = requireRole('ADMIN');
const {
  createCategorySchema,
  updateCategorySchema,
  listCategoriesSchema,
  getCategorySchema,
  deleteCategorySchema,
  reassignCategorySchema,
} = require('../validators/category.validator');

const router = Router();

router.get('/', validate(listCategoriesSchema), categoryController.list);
router.post('/', validate(createCategorySchema), categoryController.create);
router.get('/:id', validate(getCategorySchema), categoryController.getById);
router.put('/:id', validate(updateCategorySchema), categoryController.update);
router.delete('/:id', adminOnly, validate(deleteCategorySchema), categoryController.remove);
router.post('/:id/reassign', adminOnly, validate(reassignCategorySchema), categoryController.reassign);

module.exports = router;
