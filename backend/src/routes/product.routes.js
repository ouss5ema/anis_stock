const { Router } = require('express');
const productController = require('../controllers/product.controller');
const { validate } = require('../middlewares/validate.middleware');
const { requireRole } = require('../middlewares/auth.middleware');

const adminOnly = requireRole('ADMIN');
const {
  createProductSchema,
  updateProductSchema,
  listProductsSchema,
  getProductSchema,
  deleteProductSchema,
  restoreProductSchema,
} = require('../validators/product.validator');

const router = Router();

router.get('/', validate(listProductsSchema), productController.list);
router.post('/', validate(createProductSchema), productController.create);
router.get('/:id/history', validate(getProductSchema), productController.getHistory);
router.get('/:id/delete-preview', adminOnly, validate(getProductSchema), productController.deletePreview);
router.post('/:id/restore', adminOnly, validate(restoreProductSchema), productController.restore);
router.get('/:id', validate(getProductSchema), productController.getById);
router.put('/:id', validate(updateProductSchema), productController.update);
router.delete('/:id', adminOnly, validate(deleteProductSchema), productController.remove);

module.exports = router;
