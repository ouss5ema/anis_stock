const { prisma } = require('../config/prisma');
const decimal = require('../utils/decimal');
const {
  serializePurchase,
  serializeSale,
  serializeStockMovement,
  serializeProduct,
} = require('../utils/serialize');

function startOfDay(date = new Date()) {
  const value = new Date(date);
  value.setHours(0, 0, 0, 0);
  return value;
}

function endOfDay(date = new Date()) {
  const value = new Date(date);
  value.setHours(23, 59, 59, 999);
  return value;
}

function periodRange(period = 'today') {
  const to = endOfDay();
  const from = startOfDay();

  if (period === '7d') {
    from.setDate(from.getDate() - 6);
    return { from, to, period: '7d' };
  }

  if (period === '30d') {
    from.setDate(from.getDate() - 29);
    return { from, to, period: '30d' };
  }

  return { from, to, period: 'today' };
}

async function getDashboard(period = 'today') {
  const range = periodRange(period);
  const { from, to } = range;
  const confirmed = { status: 'CONFIRMED' };

  const [
    purchasesToday,
    salesToday,
    purchaseAgg,
    saleAgg,
    productCount,
    products,
    recentPurchases,
    recentSales,
    recentMovements,
    stockValueRows,
  ] = await Promise.all([
    prisma.purchase.count({
      where: { ...confirmed, purchaseDate: { gte: from, lte: to } },
    }),
    prisma.sale.count({
      where: { ...confirmed, saleDate: { gte: from, lte: to } },
    }),
    prisma.purchase.aggregate({
      where: { ...confirmed, purchaseDate: { gte: from, lte: to } },
      _sum: { totalAmount: true },
    }),
    prisma.sale.aggregate({
      where: { ...confirmed, saleDate: { gte: from, lte: to } },
      _sum: { totalAmount: true },
    }),
    prisma.product.count({ where: { isActive: true } }),
    prisma.product.findMany({
      where: { isActive: true },
      select: { currentStock: true, minimumStock: true },
    }),
    prisma.purchase.findMany({
      where: confirmed,
      orderBy: { createdAt: 'desc' },
      take: 5,
      include: {
        supplier: { select: { id: true, name: true, type: true } },
        _count: { select: { items: true } },
      },
    }),
    prisma.sale.findMany({
      where: confirmed,
      orderBy: { createdAt: 'desc' },
      take: 5,
      include: {
        customer: { select: { id: true, name: true, type: true } },
        _count: { select: { items: true } },
      },
    }),
    prisma.stockMovement.findMany({
      orderBy: { createdAt: 'desc' },
      take: 8,
      include: {
        product: { select: { id: true, sku: true, name: true, unit: true } },
      },
    }),
    prisma.$queryRaw`
      SELECT COALESCE(SUM("currentStock" * "purchasePrice"), 0) AS value
      FROM products
      WHERE "isActive" = true
    `,
  ]);

  let lowStockCount = 0;
  let outOfStockCount = 0;
  for (const product of products) {
    const current = decimal.toDecimal(product.currentStock);
    const min = decimal.toDecimal(product.minimumStock);
    if (current.lessThanOrEqualTo(0)) {
      outOfStockCount += 1;
    } else if (current.lessThanOrEqualTo(min)) {
      lowStockCount += 1;
    }
  }

  const lowStockProducts = await prisma.product.findMany({
    where: { isActive: true },
    include: { category: true },
    orderBy: { name: 'asc' },
    take: 200,
  });

  const alerts = lowStockProducts
    .filter((product) => {
      const current = decimal.toDecimal(product.currentStock);
      const min = decimal.toDecimal(product.minimumStock);
      return current.lessThanOrEqualTo(min);
    })
    .slice(0, 8)
    .map(serializeProduct);

  return {
    period: range.period,
    today: {
      purchaseCount: purchasesToday,
      saleCount: salesToday,
      purchaseAmount: decimal.toString(purchaseAgg._sum.totalAmount || 0),
      saleAmount: decimal.toString(saleAgg._sum.totalAmount || 0),
    },
    stock: {
      productCount,
      lowStockCount,
      outOfStockCount,
      approximateValue: decimal.toString(stockValueRows[0]?.value || 0),
    },
    recentPurchases: recentPurchases.map(serializePurchase),
    recentSales: recentSales.map(serializeSale),
    recentMovements: recentMovements.map(serializeStockMovement),
    stockAlerts: alerts,
  };
}

module.exports = { getDashboard };
