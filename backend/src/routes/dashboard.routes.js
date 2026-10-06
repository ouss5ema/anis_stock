const { z } = require('zod');
const { validate } = require('../middlewares/validate.middleware');
const dashboardController = require('../controllers/dashboard.controller');
const { Router } = require('express');

const listDashboardSchema = z.object({
  query: z.object({
    period: z.enum(['today', '7d', '30d']).optional().default('today'),
  }),
});

const router = Router();

router.get('/', validate(listDashboardSchema), dashboardController.get);

module.exports = router;
