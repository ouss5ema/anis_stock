const { Router } = require('express');
const categoryController = require('../controllers/category.controller');
const { validate } = require('../middlewares/validate.middleware');
const {
  createCategorySchema,
  updateCategorySchema,
  listCategoriesSchema,
  getCategorySchema,
  deleteCategorySchema,
} = require('../validators/category.validator');

const router = Router();

router.get('/', validate(listCategoriesSchema), categoryController.list);
router.post('/', validate(createCategorySchema), categoryController.create);
router.get('/:id', validate(getCategorySchema), categoryController.getById);
router.put('/:id', validate(updateCategorySchema), categoryController.update);
router.delete('/:id', validate(deleteCategorySchema), categoryController.remove);

module.exports = router;
