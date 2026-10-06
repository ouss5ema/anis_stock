const { Router } = require('express');
const purchaseController = require('../controllers/purchase.controller');
const { validate } = require('../middlewares/validate.middleware');
const {
  listPurchasesSchema,
  createPurchaseSchema,
  updatePurchaseSchema,
  getPurchaseSchema,
  deletePurchaseSchema,
} = require('../validators/purchase.validator');

const router = Router();

router.get('/', validate(listPurchasesSchema), purchaseController.list);
router.post('/', validate(createPurchaseSchema), purchaseController.create);
router.get('/:id/items', validate(getPurchaseSchema), purchaseController.listItems);
router.get('/:id', validate(getPurchaseSchema), purchaseController.getById);
router.put('/:id', validate(updatePurchaseSchema), purchaseController.update);
router.delete('/:id', validate(deletePurchaseSchema), purchaseController.remove);

module.exports = router;
