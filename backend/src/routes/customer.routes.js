const { Router } = require('express');
const customerController = require('../controllers/customer.controller');
const { validate } = require('../middlewares/validate.middleware');
const {
  createCustomerSchema,
  updateCustomerSchema,
  listCustomersSchema,
  getCustomerSchema,
  deleteCustomerSchema,
} = require('../validators/customer.validator');

const router = Router();

router.get('/', validate(listCustomersSchema), customerController.list);
router.post('/', validate(createCustomerSchema), customerController.create);
router.get('/:id', validate(getCustomerSchema), customerController.getById);
router.put('/:id', validate(updateCustomerSchema), customerController.update);
router.delete('/:id', validate(deleteCustomerSchema), customerController.remove);

module.exports = router;
