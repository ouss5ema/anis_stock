const { prisma } = require('../config/prisma');
const decimal = require('../utils/decimal');
const {
  getStockStatus,
  serializePurchase,
  serializeSale,
  serializeStockMovement,
  serializeProduct,
} = require('../utils/serialize');

function tunisDateParts(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Tunis',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const value = (type) => parts.find((part) => part.type === type)?.value;
  return {
    year: value('year'),
    month: value('month'),
    day: value('day'),
  };
}

function startOfDayTunis(date = new Date()) {
  const { year, month, day } = tunisDateParts(date);
  return new Date(`${year}-${month}-${day}T00:00:00+01:00`);
}

function endOfDayTunis(date = new Date()) {
  const { year, month, day } = tunisDateParts(date);
  return new Date(`${year}-${month}-${day}T23:59:59.999+01:00`);
}

function periodRange(period = 'today') {
  const to = endOfDayTunis();
  const startToday = startOfDayTunis();

  if (period === '7d') {
    return { from: new Date(startToday.getTime() - 6 * 24 * 60 * 60 * 1000), to, period: '7d' };
  }

  if (period === '30d') {
    return { from: new Date(startToday.getTime() - 29 * 24 * 60 * 60 * 1000), to, period: '30d' };
  }

  return { from: startToday, to, period: 'today' };
}

async function getDashboard(period = 'today') {
  const range = periodRange(period);
  const { from, to } = range;
  const confirmed = { status: 'CONFIRMED' };
  const inPeriod = { gte: from, lte: to };

  const [
    purchasesToday,
    salesToday,
    purchaseAgg,
    saleAgg,
    products,
    recentPurchases,
    recentSales,
    recentMovements,
    stockValueRows,
    topSaleItems,
  ] = await Promise.all([
    prisma.purchase.count({
      where: { ...confirmed, purchaseDate: inPeriod },
    }),
    prisma.sale.count({
      where: { ...confirmed, saleDate: inPeriod },
    }),
    prisma.purchase.aggregate({
      where: { ...confirmed, purchaseDate: inPeriod },
      _sum: { totalAmount: true },
    }),
    prisma.sale.aggregate({
      where: { ...confirmed, saleDate: inPeriod },
      _sum: { totalAmount: true },
    }),
    prisma.product.findMany({
      where: { isActive: true },
      include: { category: true },
      orderBy: { name: 'asc' },
    }),
    prisma.purchase.findMany({
      where: { ...confirmed, purchaseDate: inPeriod },
      orderBy: { createdAt: 'desc' },
      take: 5,
      include: {
        supplier: { select: { id: true, name: true, type: true } },
        _count: { select: { items: true } },
      },
    }),
    prisma.sale.findMany({
      where: { ...confirmed, saleDate: inPeriod },
      orderBy: { createdAt: 'desc' },
      take: 5,
      include: {
        customer: { select: { id: true, name: true, type: true } },
        _count: { select: { items: true } },
      },
    }),
    prisma.stockMovement.findMany({
      where: { createdAt: inPeriod },
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
    prisma.saleItem.groupBy({
      by: ['productId'],
      where: {
        sale: { ...confirmed, saleDate: inPeriod },
      },
      _sum: { quantity: true, totalPrice: true },
      orderBy: { _sum: { totalPrice: 'desc' } },
      take: 5,
    }),
  ]);

  let lowStockCount = 0;
  let outOfStockCount = 0;
  const outOfStockProducts = [];
  const lowStockProducts = [];

  for (const product of products) {
    const status = getStockStatus(product.currentStock, product.minimumStock);
    if (status === 'OUT') {
      outOfStockCount += 1;
      if (outOfStockProducts.length < 8) {
        outOfStockProducts.push(serializeProduct(product));
      }
    } else if (status === 'LOW') {
      lowStockCount += 1;
      if (lowStockProducts.length < 8) {
        lowStockProducts.push(serializeProduct(product));
      }
    }
  }

  const topProductIds = topSaleItems.map((row) => row.productId);
  const topProductRows = topProductIds.length
    ? await prisma.product.findMany({
        where: { id: { in: topProductIds } },
        select: { id: true, name: true },
      })
    : [];
  const topNames = new Map(topProductRows.map((product) => [product.id, product.name]));

  const topProducts = topSaleItems.map((row) => ({
    id: row.productId,
    name: topNames.get(row.productId) || 'Produit',
    quantity: decimal.toString(row._sum.quantity || 0),
    amount: decimal.toString(row._sum.totalPrice || 0),
  }));

  return {
    period: range.period,
    today: {
      purchaseCount: purchasesToday,
      saleCount: salesToday,
      purchaseAmount: decimal.toString(purchaseAgg._sum.totalAmount || 0),
      saleAmount: decimal.toString(saleAgg._sum.totalAmount || 0),
    },
    stock: {
      productCount: products.length,
      lowStockCount,
      outOfStockCount,
      approximateValue: decimal.toString(stockValueRows[0]?.value || 0),
    },
    recentPurchases: recentPurchases.map(serializePurchase),
    recentSales: recentSales.map(serializeSale),
    recentMovements: recentMovements.map(serializeStockMovement),
    stockAlerts: [...outOfStockProducts, ...lowStockProducts].slice(0, 8),
    outOfStockProducts,
    lowStockProducts,
    topProducts,
  };
}

module.exports = { getDashboard };
