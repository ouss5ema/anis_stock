const { Router } = require('express');
const stockController = require('../controllers/stock.controller');
const { validate } = require('../middlewares/validate.middleware');
const { requireRole } = require('../middlewares/auth.middleware');
const { listMovementsSchema, adjustStockSchema } = require('../validators/stock.validator');

const router = Router();

router.get('/movements', validate(listMovementsSchema), stockController.listMovements);
router.post('/adjustments', requireRole('ADMIN'), validate(adjustStockSchema), stockController.adjust);

module.exports = router;
