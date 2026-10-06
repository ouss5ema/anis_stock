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
  it('creates, updates and deactivates a product', async () => {
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

    const deactivated = await productService.deleteProduct(created.id);
    assert.equal(deactivated.isActive, false);

    await prisma.product.delete({ where: { id: created.id } });
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

  it('lists movements with pagination', async () => {
    const result = await stockQueryService.listMovements({ page: 1, pageSize: 5 });
    assert.ok(Array.isArray(result.items));
    assert.equal(result.pagination.page, 1);
    assert.equal(result.pagination.pageSize, 5);
  });
});
