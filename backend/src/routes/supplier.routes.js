const { Router } = require('express');
const supplierController = require('../controllers/supplier.controller');
const { validate } = require('../middlewares/validate.middleware');
const {
  createSupplierSchema,
  updateSupplierSchema,
  listSuppliersSchema,
  getSupplierSchema,
  deleteSupplierSchema,
} = require('../validators/supplier.validator');

const router = Router();

router.get('/', validate(listSuppliersSchema), supplierController.list);
router.post('/', validate(createSupplierSchema), supplierController.create);
router.get('/:id', validate(getSupplierSchema), supplierController.getById);
router.put('/:id', validate(updateSupplierSchema), supplierController.update);
router.delete('/:id', validate(deleteSupplierSchema), supplierController.remove);

module.exports = router;
