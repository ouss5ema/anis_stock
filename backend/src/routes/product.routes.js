const { Router } = require('express');
const productController = require('../controllers/product.controller');
const { validate } = require('../middlewares/validate.middleware');
const {
  createProductSchema,
  updateProductSchema,
  listProductsSchema,
  getProductSchema,
  deleteProductSchema,
} = require('../validators/product.validator');

const router = Router();

router.get('/', validate(listProductsSchema), productController.list);
router.post('/', validate(createProductSchema), productController.create);
router.get('/:id/history', validate(getProductSchema), productController.getHistory);
router.get('/:id', validate(getProductSchema), productController.getById);
router.put('/:id', validate(updateProductSchema), productController.update);
router.delete('/:id', validate(deleteProductSchema), productController.remove);

module.exports = router;
