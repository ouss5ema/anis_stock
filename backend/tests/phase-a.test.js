const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const bcrypt = require('bcrypt');

require('../src/config/env');

const { createApp } = require('../src/app');
const { prisma } = require('../src/config/prisma');
const decimal = require('../src/utils/decimal');
const saleService = require('../src/services/sale.service');
const purchaseService = require('../src/services/purchase.service');
const dashboardService = require('../src/services/dashboard.service');

const suffix = `${Date.now()}`;
const PASSWORD = 'PhaseA-Test-123!';

let server;
let baseUrl;
let adminToken;
let userToken;
const fx = {};
const created = { products: [], categories: [], sales: [], purchases: [] };

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
  return { status: response.status, payload: await response.json() };
}

async function stockOf(productId) {
  const product = await prisma.product.findUnique({ where: { id: productId } });
  return decimal.toString(product.currentStock);
}

async function makeProduct(name, categoryId = fx.category.id) {
  const product = await prisma.product.create({
    data: {
      name: `${name} ${suffix}`,
      categoryId,
      unit: 'PACK',
      purchasePrice: '10.000',
      salePrice: '12.000',
      minimumStock: '1',
      currentStock: 0,
    },
  });
  created.products.push(product.id);
  return product;
}

async function buy(items) {
  const purchase = await purchaseService.createPurchase(
    { supplierId: fx.supplier.id, items: items.map(([product, quantity]) => ({ productId: product.id, quantity, unitPrice: '10.000' })) },
    fx.admin.id
  );
  created.purchases.push(purchase.id);
  return purchase;
}

async function sell(items) {
  const sale = await saleService.createSale(
    { customerId: fx.customer.id, items: items.map(([product, quantity]) => ({ productId: product.id, quantity, unitPrice: '12.000' })) },
    fx.user.id
  );
  created.sales.push(sale.id);
  return sale;
}

async function auditFor(entityId, action) {
  return prisma.auditLog.findMany({ where: { entityId, action }, orderBy: { createdAt: 'asc' } });
}

describe('phase A: cancellations, archiving, deletions, rights and audit', () => {
  before(async () => {
    const passwordHash = await bcrypt.hash(PASSWORD, 4);
    fx.admin = await prisma.user.create({
      data: { name: 'Admin phase A', email: `admin-a-${suffix}@test.local`, passwordHash, role: 'ADMIN' },
    });
    fx.user = await prisma.user.create({
      data: { name: 'User phase A', email: `user-a-${suffix}@test.local`, passwordHash, role: 'USER' },
    });
    fx.category = await prisma.category.create({ data: { name: `TEST-A-CAT-${suffix}` } });
    fx.otherCategory = await prisma.category.create({ data: { name: `TEST-A-CAT2-${suffix}` } });
    created.categories.push(fx.category.id, fx.otherCategory.id);
    fx.supplier = await prisma.supplier.create({ data: { name: `TEST-A-FRN-${suffix}` } });
    fx.customer = await prisma.customer.create({ data: { name: `TEST-A-CLI-${suffix}` } });

    server = http.createServer(createApp());
    await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
    baseUrl = `http://127.0.0.1:${server.address().port}/api`;

    const adminLogin = await request('/auth/login', {
      method: 'POST',
      body: { email: fx.admin.email, password: PASSWORD },
    });
    assert.equal(adminLogin.status, 200);
    adminToken = adminLogin.payload.data.token;
    const userLogin = await request('/auth/login', {
      method: 'POST',
      body: { email: fx.user.email, password: PASSWORD },
    });
    assert.equal(userLogin.status, 200);
    userToken = userLogin.payload.data.token;
  });

  after(async () => {
    if (server) await new Promise((resolve) => server.close(resolve));
    const userIds = [fx.admin?.id, fx.user?.id].filter(Boolean);
    const productIds = created.products;
    await prisma.auditLog.deleteMany({ where: { userId: { in: userIds } } });
    await prisma.stockMovement.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.purchaseItem.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.saleItem.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.purchase.deleteMany({ where: { id: { in: created.purchases } } });
    await prisma.sale.deleteMany({ where: { id: { in: created.sales } } });
    await prisma.productSupplier.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.product.deleteMany({ where: { id: { in: productIds } } });
    await prisma.category.deleteMany({ where: { id: { in: created.categories } } });
    if (fx.customer) await prisma.customer.delete({ where: { id: fx.customer.id } });
    if (fx.supplier) await prisma.supplier.delete({ where: { id: fx.supplier.id } });
    await prisma.user.deleteMany({ where: { id: { in: userIds } } });
    await prisma.$disconnect();
  });

  it('cancels a 3-line sale: every stock returns exactly to its initial value', async () => {
    const products = [await makeProduct('A1'), await makeProduct('A2'), await makeProduct('A3')];
    await buy(products.map((product) => [product, '10']));
    const initial = await Promise.all(products.map((product) => stockOf(product.id)));
    const sale = await sell([
      [products[0], '3'],
      [products[1], '2.5'],
      [products[2], '1'],
    ]);
    assert.notDeepEqual(await Promise.all(products.map((product) => stockOf(product.id))), initial);

    const result = await request(`/sales/${sale.id}`, {
      method: 'DELETE',
      token: adminToken,
      body: { reason: 'Erreur de saisie' },
    });
    assert.equal(result.status, 200);
    assert.equal(result.payload.data.status, 'CANCELLED');
    assert.equal(result.payload.data.cancelReason, 'Erreur de saisie');
    assert.equal(result.payload.data.cancelledById, fx.admin.id);
    assert.equal(result.payload.data.cancelledBy.name, 'Admin phase A');

    assert.deepEqual(await Promise.all(products.map((product) => stockOf(product.id))), initial);
    const returns = await prisma.stockMovement.findMany({
      where: { referenceId: sale.id, type: 'RETURN_SALE' },
    });
    assert.equal(returns.length, 3);
    assert.ok(returns.every((movement) => movement.createdById === fx.admin.id));

    const [entry] = await auditFor(sale.id, 'SALE_CANCELLED');
    assert.ok(entry);
    assert.equal(entry.userId, fx.admin.id);
    assert.equal(entry.reason, 'Erreur de saisie');
    assert.equal(entry.metadata.stock.length, 3);
    const first = entry.metadata.stock.find((line) => line.productId === products[0].id);
    assert.equal(first.stockBefore, '7.000');
    assert.equal(first.stockAfter, '10.000');
  });

  it('refuses a second cancellation (409 ALREADY_CANCELLED) and leaves stock unchanged', async () => {
    const product = await makeProduct('B');
    await buy([[product, '5']]);
    const sale = await sell([[product, '2']]);
    await saleService.cancelSale(sale.id, fx.admin.id, 'Retour client');
    const stockAfterFirst = await stockOf(product.id);

    const second = await request(`/sales/${sale.id}`, {
      method: 'DELETE',
      token: adminToken,
      body: { reason: 'Doublon' },
    });
    assert.equal(second.status, 409);
    assert.equal(second.payload.code, 'ALREADY_CANCELLED');
    assert.equal(await stockOf(product.id), stockAfterFirst);
    assert.equal((await auditFor(sale.id, 'SALE_CANCELLED')).length, 1);
  });

  it('handles two concurrent cancellations: exactly one succeeds, stock is restored once', async () => {
    const products = [await makeProduct('C1'), await makeProduct('C2')];
    await buy(products.map((product) => [product, '10']));
    const initial = await Promise.all(products.map((product) => stockOf(product.id)));
    const sale = await sell([
      [products[0], '4'],
      [products[1], '6'],
    ]);

    const results = await Promise.allSettled([
      saleService.cancelSale(sale.id, fx.admin.id, 'Concurrence 1'),
      saleService.cancelSale(sale.id, fx.admin.id, 'Concurrence 2'),
    ]);
    const fulfilled = results.filter((result) => result.status === 'fulfilled');
    const rejected = results.filter((result) => result.status === 'rejected');
    assert.equal(fulfilled.length, 1);
    assert.equal(rejected.length, 1);
    assert.equal(rejected[0].reason.code, 'ALREADY_CANCELLED');

    assert.deepEqual(await Promise.all(products.map((product) => stockOf(product.id))), initial);
    const returns = await prisma.stockMovement.count({ where: { referenceId: sale.id, type: 'RETURN_SALE' } });
    assert.equal(returns, 2);
    assert.equal((await auditFor(sale.id, 'SALE_CANCELLED')).length, 1);
  });

  it('refuses a purchase cancellation when goods were sold, with a full rollback', async () => {
    const sold = await makeProduct('D sold');
    const untouched = await makeProduct('D other');
    const purchase = await buy([
      [sold, '10'],
      [untouched, '5'],
    ]);
    await sell([[sold, '7']]);
    const before = [await stockOf(sold.id), await stockOf(untouched.id)];

    const preview = await request(`/purchases/${purchase.id}/cancel-preview`, { token: adminToken });
    assert.equal(preview.status, 200);
    assert.equal(preview.payload.data.canCancel, false);
    assert.ok(preview.payload.data.lines.find((line) => line.productId === sold.id).blocking);

    const result = await request(`/purchases/${purchase.id}`, {
      method: 'DELETE',
      token: adminToken,
      body: { reason: 'Erreur de saisie' },
    });
    assert.equal(result.status, 409);
    assert.equal(result.payload.code, 'INSUFFICIENT_STOCK');
    assert.match(result.payload.message, /stock actuel/);
    assert.equal(result.payload.errors[0].productId, sold.id);
    assert.equal(result.payload.errors[0].available, '3.000');
    assert.equal(result.payload.errors[0].required, '10.000');

    assert.deepEqual([await stockOf(sold.id), await stockOf(untouched.id)], before);
    const fresh = await prisma.purchase.findUnique({ where: { id: purchase.id } });
    assert.equal(fresh.status, 'CONFIRMED');
    assert.equal(fresh.cancelledAt, null);
    assert.equal(await prisma.stockMovement.count({ where: { referenceId: purchase.id, type: 'RETURN_PURCHASE' } }), 0);
    assert.equal((await auditFor(purchase.id, 'PURCHASE_CANCELLED')).length, 0);
  });

  it('cancels a purchase when stock allows it, with audit', async () => {
    const product = await makeProduct('E');
    const purchase = await buy([[product, '4']]);
    const result = await request(`/purchases/${purchase.id}`, {
      method: 'DELETE',
      token: adminToken,
      body: { reason: 'Doublon' },
    });
    assert.equal(result.status, 200);
    assert.equal(result.payload.data.status, 'CANCELLED');
    assert.equal(await stockOf(product.id), '0.000');
    assert.equal((await auditFor(purchase.id, 'PURCHASE_CANCELLED')).length, 1);
  });

  it('requires a reason of 3 to 300 characters (422)', async () => {
    const product = await makeProduct('F');
    await buy([[product, '2']]);
    const sale = await sell([[product, '1']]);
    for (const body of [undefined, {}, { reason: 'ab' }, { reason: 'x'.repeat(301) }]) {
      const result = await request(`/sales/${sale.id}`, { method: 'DELETE', token: adminToken, body });
      assert.equal(result.status, 422, JSON.stringify(body));
    }
    assert.equal((await prisma.sale.findUnique({ where: { id: sale.id } })).status, 'CONFIRMED');
  });

  it('refuses to modify a cancelled sale or purchase (409 DOCUMENT_CANCELLED)', async () => {
    const product = await makeProduct('G');
    const purchase = await buy([[product, '5']]);
    const sale = await sell([[product, '1']]);
    await saleService.cancelSale(sale.id, fx.admin.id, 'Erreur de saisie');

    const saleUpdate = await request(`/sales/${sale.id}`, {
      method: 'PUT',
      token: adminToken,
      body: { items: [{ productId: product.id, quantity: '2', unitPrice: '12.000' }] },
    });
    assert.equal(saleUpdate.status, 409);
    assert.equal(saleUpdate.payload.code, 'DOCUMENT_CANCELLED');

    await purchaseService.cancelPurchase(purchase.id, fx.admin.id, 'Erreur de saisie');
    const purchaseUpdate = await request(`/purchases/${purchase.id}`, {
      method: 'PUT',
      token: adminToken,
      body: { notes: 'modif' },
    });
    assert.equal(purchaseUpdate.status, 409);
    assert.equal(purchaseUpdate.payload.code, 'DOCUMENT_CANCELLED');
  });

  it('audits an admin sale update with lines before and after', async () => {
    const product = await makeProduct('H');
    await buy([[product, '10']]);
    const sale = await sell([[product, '2']]);
    const result = await request(`/sales/${sale.id}`, {
      method: 'PUT',
      token: adminToken,
      body: { items: [{ productId: product.id, quantity: '5', unitPrice: '12.000' }] },
    });
    assert.equal(result.status, 200);
    assert.equal(await stockOf(product.id), '5.000');
    const [entry] = await auditFor(sale.id, 'SALE_UPDATED');
    assert.equal(entry.metadata.before.lines[0].quantity, '2');
    assert.equal(entry.metadata.after.lines[0].quantity, '5');
  });

  it('archives a product with history, keeps its stock, lists it in Archivés and restores it', async () => {
    const product = await makeProduct('I');
    await buy([[product, '3']]);

    const preview = await request(`/products/${product.id}/delete-preview`, { token: adminToken });
    assert.equal(preview.payload.data.mode, 'ARCHIVE');
    assert.equal(preview.payload.data.hasStock, true);

    const result = await request(`/products/${product.id}`, {
      method: 'DELETE',
      token: adminToken,
      body: { reason: 'Plus vendu' },
    });
    assert.equal(result.status, 200);
    assert.equal(result.payload.data.deletionMode, 'ARCHIVED');
    assert.equal(result.payload.data.isArchived, true);
    assert.ok(result.payload.data.archivedAt);
    assert.equal(await stockOf(product.id), '3.000');
    assert.equal((await auditFor(product.id, 'PRODUCT_ARCHIVED')).length, 1);

    const active = await request(`/products?pageSize=100&search=${encodeURIComponent(product.name)}`, { token: userToken });
    assert.equal(active.payload.data.items.length, 0);
    const archived = await request(`/products?archived=true&pageSize=100&search=${encodeURIComponent(product.name)}`, {
      token: userToken,
    });
    assert.equal(archived.payload.data.items.length, 1);

    const again = await request(`/products/${product.id}`, { method: 'DELETE', token: adminToken });
    assert.equal(again.status, 409);
    assert.equal(again.payload.code, 'ALREADY_ARCHIVED');

    const restored = await request(`/products/${product.id}/restore`, { method: 'POST', token: adminToken });
    assert.equal(restored.status, 200);
    assert.equal(restored.payload.data.isActive, true);
    assert.equal(restored.payload.data.archivedAt, null);
    assert.equal((await auditFor(product.id, 'PRODUCT_RESTORED')).length, 1);
  });

  it('really deletes a product without history (audited)', async () => {
    const product = await makeProduct('J');
    const preview = await request(`/products/${product.id}/delete-preview`, { token: adminToken });
    assert.equal(preview.payload.data.mode, 'DELETE');

    const result = await request(`/products/${product.id}`, { method: 'DELETE', token: adminToken });
    assert.equal(result.status, 200);
    assert.equal(result.payload.data.deletionMode, 'DELETED');
    assert.equal(await prisma.product.findUnique({ where: { id: product.id } }), null);
    assert.equal((await auditFor(product.id, 'PRODUCT_DELETED')).length, 1);
  });

  it('refuses to delete a non-empty category, reassigns its products, then deletes it', async () => {
    const category = await prisma.category.create({ data: { name: `TEST-A-CAT3-${suffix}` } });
    created.categories.push(category.id);
    const inUse = await makeProduct('K', category.id);
    const archived = await makeProduct('K archived', category.id);
    await prisma.product.update({ where: { id: archived.id }, data: { isActive: false } });

    const refused = await request(`/categories/${category.id}`, { method: 'DELETE', token: adminToken });
    assert.equal(refused.status, 409);
    assert.equal(refused.payload.code, 'CATEGORY_NOT_EMPTY');
    assert.equal(refused.payload.errors[0].productCount, 2);

    const sameTarget = await request(`/categories/${category.id}/reassign`, {
      method: 'POST',
      token: adminToken,
      body: { targetCategoryId: category.id },
    });
    assert.equal(sameTarget.status, 400);
    assert.equal(sameTarget.payload.code, 'INVALID_TARGET_CATEGORY');

    const moved = await request(`/categories/${category.id}/reassign`, {
      method: 'POST',
      token: adminToken,
      body: { targetCategoryId: fx.otherCategory.id },
    });
    assert.equal(moved.status, 200);
    assert.equal(moved.payload.data.movedCount, 2);
    assert.equal((await prisma.product.findUnique({ where: { id: inUse.id } })).categoryId, fx.otherCategory.id);
    assert.equal((await auditFor(category.id, 'CATEGORY_PRODUCTS_REASSIGNED')).length, 1);

    const deleted = await request(`/categories/${category.id}`, { method: 'DELETE', token: adminToken });
    assert.equal(deleted.status, 200);
    assert.equal(await prisma.category.findUnique({ where: { id: category.id } }), null);
    assert.equal((await auditFor(category.id, 'CATEGORY_DELETED')).length, 1);
  });

  it('excludes cancelled sales and purchases from the dashboard totals', async () => {
    const product = await makeProduct('L');
    const purchase = await buy([[product, '10']]);
    const sale = await sell([[product, '3']]);
    const withDocs = await dashboardService.getDashboard('today');

    await saleService.cancelSale(sale.id, fx.admin.id, 'Erreur de saisie');
    await purchaseService.cancelPurchase(purchase.id, fx.admin.id, 'Erreur de saisie');
    const without = await dashboardService.getDashboard('today');

    assert.equal(without.today.saleCount, withDocs.today.saleCount - 1);
    assert.equal(without.today.purchaseCount, withDocs.today.purchaseCount - 1);
    assert.equal(
      decimal.toString(decimal.subtract(withDocs.today.saleAmount, without.today.saleAmount)),
      '36.000'
    );
    assert.equal(
      decimal.toString(decimal.subtract(withDocs.today.purchaseAmount, without.today.purchaseAmount)),
      '100.000'
    );
  });

  it('audits customer and supplier deletions (deactivation, no physical delete)', async () => {
    const customer = await prisma.customer.create({ data: { name: `TEST-A-CLI2-${suffix}` } });
    const supplier = await prisma.supplier.create({ data: { name: `TEST-A-FRN2-${suffix}` } });
    const c = await request(`/customers/${customer.id}`, { method: 'DELETE', token: adminToken });
    const s = await request(`/suppliers/${supplier.id}`, { method: 'DELETE', token: adminToken });
    assert.equal(c.status, 200);
    assert.equal(s.status, 200);
    assert.equal((await prisma.customer.findUnique({ where: { id: customer.id } })).isActive, false);
    assert.equal((await prisma.supplier.findUnique({ where: { id: supplier.id } })).isActive, false);
    assert.equal((await auditFor(customer.id, 'CUSTOMER_DELETED')).length, 1);
    assert.equal((await auditFor(supplier.id, 'SUPPLIER_DELETED')).length, 1);
    await prisma.auditLog.deleteMany({ where: { entityId: { in: [customer.id, supplier.id] } } });
    await prisma.customer.delete({ where: { id: customer.id } });
    await prisma.supplier.delete({ where: { id: supplier.id } });
  });

  it('returns 403 FORBIDDEN to a USER on every ADMIN route, without side effects', async () => {
    const product = await makeProduct('M');
    const purchase = await buy([[product, '5']]);
    const sale = await sell([[product, '1']]);
    const stockBefore = await stockOf(product.id);
    const reason = { reason: 'Tentative USER' };

    const attempts = [
      ['DELETE', `/sales/${sale.id}`, reason],
      ['PUT', `/sales/${sale.id}`, { notes: 'x' }],
      ['GET', `/sales/${sale.id}/cancel-preview`],
      ['DELETE', `/purchases/${purchase.id}`, reason],
      ['PUT', `/purchases/${purchase.id}`, { notes: 'x' }],
      ['GET', `/purchases/${purchase.id}/cancel-preview`],
      ['DELETE', `/products/${product.id}`],
      ['GET', `/products/${product.id}/delete-preview`],
      ['POST', `/products/${product.id}/restore`],
      ['PUT', `/products/${product.id}`, { isActive: false }],
      ['DELETE', `/categories/${fx.otherCategory.id}`],
      ['POST', `/categories/${fx.otherCategory.id}/reassign`, { targetCategoryId: fx.category.id }],
      ['DELETE', `/customers/${fx.customer.id}`],
      ['DELETE', `/suppliers/${fx.supplier.id}`],
      ['POST', '/stock/adjustments', { productId: product.id, direction: 'in', quantity: '1', reason: 'Tentative USER' }],
    ];
    for (const [method, path, body] of attempts) {
      const result = await request(path, { method, token: userToken, body });
      assert.equal(result.status, 403, `${method} ${path}`);
      assert.equal(result.payload.code, 'FORBIDDEN', `${method} ${path}`);
    }

    assert.equal(await stockOf(product.id), stockBefore);
    assert.equal((await prisma.sale.findUnique({ where: { id: sale.id } })).status, 'CONFIRMED');
    assert.equal((await prisma.purchase.findUnique({ where: { id: purchase.id } })).status, 'CONFIRMED');
    assert.equal((await prisma.product.findUnique({ where: { id: product.id } })).isActive, true);
    assert.equal((await prisma.customer.findUnique({ where: { id: fx.customer.id } })).isActive, true);
    assert.equal((await prisma.supplier.findUnique({ where: { id: fx.supplier.id } })).isActive, true);
  });

  it('still lets a USER create sales and purchases', async () => {
    const product = await makeProduct('N');
    const purchase = await request('/purchases', {
      method: 'POST',
      token: userToken,
      body: { supplierId: fx.supplier.id, items: [{ productId: product.id, quantity: '2', unitPrice: '10.000' }] },
    });
    assert.equal(purchase.status, 201);
    created.purchases.push(purchase.payload.data.id);
    const sale = await request('/sales', {
      method: 'POST',
      token: userToken,
      body: { customerId: fx.customer.id, items: [{ productId: product.id, quantity: '1', unitPrice: '12.000' }] },
    });
    assert.equal(sale.status, 201);
    created.sales.push(sale.payload.data.id);
  });

  it('shows the stock consequences in the sale cancel preview', async () => {
    const product = await makeProduct('O');
    await buy([[product, '8']]);
    const sale = await sell([[product, '3']]);
    const preview = await request(`/sales/${sale.id}/cancel-preview`, { token: adminToken });
    assert.equal(preview.status, 200);
    assert.equal(preview.payload.data.canCancel, true);
    assert.equal(preview.payload.data.lines[0].stockBefore, '5.000');
    assert.equal(preview.payload.data.lines[0].stockAfter, '8.000');
  });
});
