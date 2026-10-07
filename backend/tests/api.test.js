const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');

require('../src/config/env');

const { createApp } = require('../src/app');
const { prisma } = require('../src/config/prisma');
const dashboardService = require('../src/services/dashboard.service');
const productService = require('../src/services/product.service');
const stockQueryService = require('../src/services/stock-query.service');

let server;
let baseUrl;
let adminToken;
let userToken;

async function request(path, { method = 'GET', token, body } = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const payload = await response.json();
  return { status: response.status, payload };
}

describe('auth and protected API', () => {
  before(async () => {
    const app = createApp();
    server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    const { port } = server.address();
    baseUrl = `http://127.0.0.1:${port}/api`;

    const adminLogin = await request('/auth/login', {
      method: 'POST',
      body: { email: 'admin@stock.local', password: 'Admin123!' },
    });
    assert.equal(adminLogin.status, 200);
    adminToken = adminLogin.payload.data.token;

    const userLogin = await request('/auth/login', {
      method: 'POST',
      body: { email: 'user@stock.local', password: 'User123!' },
    });
    assert.equal(userLogin.status, 200);
    userToken = userLogin.payload.data.token;
  });

  after(async () => {
    if (server) {
      await new Promise((resolve) => server.close(resolve));
    }
    await prisma.$disconnect();
  });

  it('rejects invalid login credentials', async () => {
    const result = await request('/auth/login', {
      method: 'POST',
      body: { email: 'admin@stock.local', password: 'WrongPass1!' },
    });
    assert.equal(result.status, 401);
    assert.equal(result.payload.success, false);
  });

  it('rejects protected routes without a token', async () => {
    const result = await request('/products');
    assert.equal(result.status, 401);
    assert.equal(result.payload.success, false);
  });

  it('rejects an invalid token', async () => {
    const result = await request('/products', { token: 'not-a-valid-token' });
    assert.equal(result.status, 401);
  });

  it('returns the authenticated user', async () => {
    const result = await request('/auth/me', { token: adminToken });
    assert.equal(result.status, 200);
    assert.equal(result.payload.data.email, 'admin@stock.local');
    assert.equal(result.payload.data.role, 'ADMIN');
    assert.equal(result.payload.data.passwordHash, undefined);
  });

  it('forbids a USER from adjusting stock', async () => {
    const products = await request('/products?pageSize=1', { token: userToken });
    assert.equal(products.status, 200);
    const productId = products.payload.data.items[0].id;
    const result = await request('/stock/adjustments', {
      method: 'POST',
      token: userToken,
      body: {
        productId,
        direction: 'in',
        quantity: '1',
        reason: 'Should be forbidden',
      },
    });
    assert.equal(result.status, 403);
  });

  it('validates product creation payload with 422', async () => {
    const result = await request('/products', {
      method: 'POST',
      token: adminToken,
      body: { name: 'X' },
    });
    assert.equal(result.status, 422);
    assert.equal(result.payload.success, false);
  });

  it('health endpoint reports the database', async () => {
    const result = await request('/health');
    assert.equal(result.status, 200);
    assert.equal(result.payload.data.database, 'up');
  });
});

describe('product, dashboard and stock queries', () => {
  it('creates, updates and deletes a product without history', async () => {
    const category = await prisma.category.findFirst({ where: { isActive: true } });
    assert.ok(category);

    const sku = `TEST-P-${Date.now()}`;
    const created = await productService.createProduct({
      sku,
      name: 'Produit API test',
      categoryId: category.id,
      unit: 'PACK',
      purchasePrice: '8.000',
      salePrice: '10.000',
      minimumStock: '2',
    });
    assert.equal(created.currentStock, '0.000');
    assert.equal(created.sku, sku);

    const updated = await productService.updateProduct(created.id, { name: 'Produit API test 2' });
    assert.equal(updated.name, 'Produit API test 2');

    // Phase A: no movement, no document line, zero stock -> real deletion.
    const deleted = await productService.deleteProduct(created.id);
    assert.equal(deleted.deletionMode, 'DELETED');
    assert.equal(await prisma.product.findUnique({ where: { id: created.id } }), null);
  });

  it('creates products without SKU and keeps SKU unique when present', async () => {
    const category = await prisma.category.findFirst({ where: { isActive: true } });
    assert.ok(category);

    const first = await productService.createProduct({
      name: 'Produit sans SKU 1',
      categoryId: category.id,
      unit: 'PACK',
      purchasePrice: '1.000',
      salePrice: '2.000',
      minimumStock: '5',
    });
    const second = await productService.createProduct({
      sku: '',
      name: 'Produit sans SKU 2',
      categoryId: category.id,
      unit: 'PACK',
      purchasePrice: '1.000',
      salePrice: '2.000',
      minimumStock: '5',
    });
    assert.equal(first.sku, null);
    assert.equal(second.sku, null);
    assert.equal(first.stockStatus, 'OUT');

    const withSku = await productService.createProduct({
      sku: `TEST-SKU-${Date.now()}`,
      name: 'Produit avec SKU',
      categoryId: category.id,
      unit: 'PACK',
      purchasePrice: '1.000',
      salePrice: '2.000',
      minimumStock: '0',
    });
    assert.ok(withSku.sku);

    await prisma.product.deleteMany({ where: { id: { in: [first.id, second.id, withSku.id] } } });
  });

  it('computes stock statuses from current and minimum stock', async () => {
    const { getStockStatus } = require('../src/utils/serialize');
    assert.equal(getStockStatus(0, 5), 'OUT');
    assert.equal(getStockStatus(1, 5), 'LOW');
    assert.equal(getStockStatus(5, 5), 'LOW');
    assert.equal(getStockStatus(6, 5), 'NORMAL');
    assert.equal(getStockStatus(1, 0), 'NORMAL');
  });

  it('returns dashboard statistics consistent with confirmed documents', async () => {
    const dashboard = await dashboardService.getDashboard('30d');
    const [purchaseCount, saleCount] = await Promise.all([
      prisma.purchase.count({
        where: {
          status: 'CONFIRMED',
          purchaseDate: {
            gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
          },
        },
      }),
      prisma.sale.count({
        where: {
          status: 'CONFIRMED',
          saleDate: {
            gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
          },
        },
      }),
    ]);

    assert.equal(typeof dashboard.today.purchaseCount, 'number');
    assert.equal(typeof dashboard.today.saleCount, 'number');
    assert.ok(dashboard.today.purchaseCount <= purchaseCount);
    assert.ok(dashboard.today.saleCount <= saleCount);
    assert.ok(dashboard.stock.productCount >= 0);
    assert.match(dashboard.stock.approximateValue, /^\d+\.\d{3}$/);
  });

  it('computes a previous period of the same duration right before the current one', () => {
    for (const period of ['today', '7d', '30d']) {
      const range = dashboardService.periodRange(period);
      const previous = dashboardService.previousRange(range);
      assert.equal(
        previous.to.getTime() - previous.from.getTime(),
        range.to.getTime() - range.from.getTime()
      );
      assert.equal(previous.to.getTime(), range.from.getTime() - 1);
    }
  });

  it('builds a continuous daily series for 7d and 30d', () => {
    for (const [period, days] of [['7d', 7], ['30d', 30]]) {
      const buckets = dashboardService.seriesBuckets(dashboardService.periodRange(period));
      assert.equal(buckets.granularity, 'day');
      assert.equal(buckets.keys.length, days);
      assert.equal(new Set(buckets.keys).size, days);
      assert.deepEqual([...buckets.keys].sort(), buckets.keys);
      buckets.keys.forEach((key) => assert.match(key, /^\d{4}-\d{2}-\d{2}$/));
    }
  });

  it('builds a continuous hourly series for today', () => {
    const buckets = dashboardService.seriesBuckets(dashboardService.periodRange('today'));
    assert.equal(buckets.granularity, 'hour');
    assert.equal(buckets.keys.length, 24);
    assert.match(buckets.keys[0], /^\d{4}-\d{2}-\d{2}T00:00$/);
    assert.match(buckets.keys[23], /^\d{4}-\d{2}-\d{2}T23:00$/);
    assert.equal(new Set(buckets.keys).size, buckets.keys.length);
  });

  it('returns series and previous totals consistent with the period aggregates', async () => {
    const { Prisma } = require('@prisma/client');
    for (const period of ['today', '7d', '30d']) {
      const dashboard = await dashboardService.getDashboard(period);

      assert.ok(Array.isArray(dashboard.series));
      assert.equal(dashboard.seriesGranularity, period === 'today' ? 'hour' : 'day');
      let saleTotal = new Prisma.Decimal(0);
      let purchaseTotal = new Prisma.Decimal(0);
      let saleCount = 0;
      let purchaseCount = 0;
      for (const point of dashboard.series) {
        assert.match(point.saleAmount, /^\d+\.\d{3}$/);
        assert.match(point.purchaseAmount, /^\d+\.\d{3}$/);
        saleTotal = saleTotal.plus(point.saleAmount);
        purchaseTotal = purchaseTotal.plus(point.purchaseAmount);
        saleCount += point.saleCount;
        purchaseCount += point.purchaseCount;
      }
      assert.equal(saleTotal.toFixed(3), dashboard.today.saleAmount);
      assert.equal(purchaseTotal.toFixed(3), dashboard.today.purchaseAmount);
      assert.equal(saleCount, dashboard.today.saleCount);
      assert.equal(purchaseCount, dashboard.today.purchaseCount);

      assert.equal(typeof dashboard.previous.saleCount, 'number');
      assert.equal(typeof dashboard.previous.purchaseCount, 'number');
      assert.match(dashboard.previous.saleAmount, /^\d+\.\d{3}$/);
      assert.match(dashboard.previous.purchaseAmount, /^\d+\.\d{3}$/);
      assert.ok(dashboard.previous.from < dashboard.previous.to);
    }
  });

  it('lists movements with pagination', async () => {
    const result = await stockQueryService.listMovements({ page: 1, pageSize: 5 });
    assert.ok(Array.isArray(result.items));
    assert.equal(result.pagination.page, 1);
    assert.equal(result.pagination.pageSize, 5);
  });
});
