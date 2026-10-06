const { Router } = require('express');
const { authenticateActive } = require('../middlewares/auth.middleware');
const { prisma } = require('../config/prisma');
const authRoutes = require('./auth.routes');
const categoryRoutes = require('./category.routes');
const productRoutes = require('./product.routes');
const supplierRoutes = require('./supplier.routes');
const customerRoutes = require('./customer.routes');
const purchaseRoutes = require('./purchase.routes');
const saleRoutes = require('./sale.routes');
const stockRoutes = require('./stock.routes');
const dashboardRoutes = require('./dashboard.routes');

const router = Router();

router.get('/health', async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return res.json({
      success: true,
      data: {
        status: 'ok',
        database: 'up',
        timestamp: new Date().toISOString(),
      },
      message: 'API is running',
    });
  } catch {
    return res.status(503).json({
      success: false,
      message: 'Database unavailable',
      errors: [],
    });
  }
});

router.use('/auth', authRoutes);
router.use('/categories', ...authenticateActive, categoryRoutes);
router.use('/products', ...authenticateActive, productRoutes);
router.use('/suppliers', ...authenticateActive, supplierRoutes);
router.use('/customers', ...authenticateActive, customerRoutes);
router.use('/purchases', ...authenticateActive, purchaseRoutes);
router.use('/sales', ...authenticateActive, saleRoutes);
router.use('/stock', ...authenticateActive, stockRoutes);
router.use('/dashboard', ...authenticateActive, dashboardRoutes);

module.exports = router;
