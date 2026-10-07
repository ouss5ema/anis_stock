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

const DAY_MS = 24 * 60 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

function tunisHour(date) {
  return new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Tunis',
    hour: '2-digit',
    hourCycle: 'h23',
  }).format(date);
}

function dayKey(date) {
  const { year, month, day } = tunisDateParts(date);
  return `${year}-${month}-${day}`;
}

function hourKey(date) {
  return `${dayKey(date)}T${tunisHour(date)}:00`;
}

/**
 * Continuous list of bucket keys for the period (Africa/Tunis):
 * one per day for 7d/30d, one per hour (00:00 to 23:00) for today.
 */
function seriesBuckets(range) {
  if (range.period === 'today') {
    const keys = [];
    for (let time = range.from.getTime(); time <= range.to.getTime(); time += HOUR_MS) {
      keys.push(hourKey(new Date(time)));
    }
    return { granularity: 'hour', keys };
  }

  const keys = [];
  for (let time = range.from.getTime(); time <= range.to.getTime(); time += DAY_MS) {
    keys.push(dayKey(new Date(time)));
  }
  return { granularity: 'day', keys };
}

/** Same duration, immediately before the current period. */
function previousRange(range) {
  const duration = range.to.getTime() - range.from.getTime() + 1;
  return {
    from: new Date(range.from.getTime() - duration),
    to: new Date(range.from.getTime() - 1),
  };
}

// Read-only aggregations. Dates are stored in UTC (timestamp without time zone)
// and bucketed in Africa/Tunis, like the period bounds above.
function aggregateSalesByBucket(from, to, format) {
  return prisma.$queryRaw`
    SELECT to_char(("saleDate" AT TIME ZONE 'UTC') AT TIME ZONE 'Africa/Tunis', ${format}) AS bucket,
           COALESCE(SUM("totalAmount"), 0) AS amount,
           COUNT(*)::int AS count
    FROM sales
    WHERE status = 'CONFIRMED' AND "saleDate" >= ${from} AND "saleDate" <= ${to}
    GROUP BY bucket
  `;
}

function aggregatePurchasesByBucket(from, to, format) {
  return prisma.$queryRaw`
    SELECT to_char(("purchaseDate" AT TIME ZONE 'UTC') AT TIME ZONE 'Africa/Tunis', ${format}) AS bucket,
           COALESCE(SUM("totalAmount"), 0) AS amount,
           COUNT(*)::int AS count
    FROM purchases
    WHERE status = 'CONFIRMED' AND "purchaseDate" >= ${from} AND "purchaseDate" <= ${to}
    GROUP BY bucket
  `;
}

const BUCKET_FORMATS = {
  day: 'YYYY-MM-DD',
  hour: 'YYYY-MM-DD"T"HH24":00"',
};

function buildSeries(buckets, saleRows, purchaseRows) {
  const sales = new Map(saleRows.map((row) => [row.bucket, row]));
  const purchases = new Map(purchaseRows.map((row) => [row.bucket, row]));
  return buckets.keys.map((key) => ({
    date: key,
    saleAmount: decimal.toString(sales.get(key)?.amount || 0),
    saleCount: Number(sales.get(key)?.count || 0),
    purchaseAmount: decimal.toString(purchases.get(key)?.amount || 0),
    purchaseCount: Number(purchases.get(key)?.count || 0),
  }));
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
  const previous = previousRange(range);
  const inPreviousPeriod = { gte: previous.from, lte: previous.to };
  const buckets = seriesBuckets(range);
  const bucketFormat = BUCKET_FORMATS[buckets.granularity];

  const extrasPromise = Promise.all([
    prisma.purchase.count({ where: { ...confirmed, purchaseDate: inPreviousPeriod } }),
    prisma.sale.count({ where: { ...confirmed, saleDate: inPreviousPeriod } }),
    prisma.purchase.aggregate({
      where: { ...confirmed, purchaseDate: inPreviousPeriod },
      _sum: { totalAmount: true },
    }),
    prisma.sale.aggregate({
      where: { ...confirmed, saleDate: inPreviousPeriod },
      _sum: { totalAmount: true },
    }),
    aggregateSalesByBucket(from, to, bucketFormat),
    aggregatePurchasesByBucket(from, to, bucketFormat),
  ]);

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
    extras,
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
    extrasPromise,
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

  const [
    previousPurchaseCount,
    previousSaleCount,
    previousPurchaseAgg,
    previousSaleAgg,
    saleBuckets,
    purchaseBuckets,
  ] = extras;

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
    previous: {
      from: previous.from,
      to: previous.to,
      purchaseCount: previousPurchaseCount,
      saleCount: previousSaleCount,
      purchaseAmount: decimal.toString(previousPurchaseAgg._sum.totalAmount || 0),
      saleAmount: decimal.toString(previousSaleAgg._sum.totalAmount || 0),
    },
    seriesGranularity: buckets.granularity,
    series: buildSeries(buckets, saleBuckets, purchaseBuckets),
  };
}

module.exports = { getDashboard, periodRange, previousRange, seriesBuckets };
