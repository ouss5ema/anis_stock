const { Router } = require('express');
const saleController = require('../controllers/sale.controller');
const { validate } = require('../middlewares/validate.middleware');
const { requireRole } = require('../middlewares/auth.middleware');

const adminOnly = requireRole('ADMIN');
const {
  listSalesSchema,
  createSaleSchema,
  updateSaleSchema,
  getSaleSchema,
  deleteSaleSchema,
} = require('../validators/sale.validator');

const router = Router();

router.get('/', validate(listSalesSchema), saleController.list);
router.post('/', validate(createSaleSchema), saleController.create);
router.get('/:id/items', validate(getSaleSchema), saleController.listItems);
router.get('/:id/cancel-preview', adminOnly, validate(getSaleSchema), saleController.cancelPreview);
router.get('/:id', validate(getSaleSchema), saleController.getById);
router.put('/:id', adminOnly, validate(updateSaleSchema), saleController.update);
router.delete('/:id', adminOnly, validate(deleteSaleSchema), saleController.remove);

module.exports = router;
