const { Router } = require('express');
const saleController = require('../controllers/sale.controller');
const { validate } = require('../middlewares/validate.middleware');
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
router.get('/:id', validate(getSaleSchema), saleController.getById);
router.put('/:id', validate(updateSaleSchema), saleController.update);
router.delete('/:id', validate(deleteSaleSchema), saleController.remove);

module.exports = router;
