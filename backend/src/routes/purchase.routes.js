const { Router } = require('express');
const purchaseController = require('../controllers/purchase.controller');
const { validate } = require('../middlewares/validate.middleware');
const { requireRole } = require('../middlewares/auth.middleware');

const adminOnly = requireRole('ADMIN');
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
router.get('/:id/cancel-preview', adminOnly, validate(getPurchaseSchema), purchaseController.cancelPreview);
router.get('/:id', validate(getPurchaseSchema), purchaseController.getById);
router.put('/:id', adminOnly, validate(updatePurchaseSchema), purchaseController.update);
router.delete('/:id', adminOnly, validate(deletePurchaseSchema), purchaseController.remove);

module.exports = router;
