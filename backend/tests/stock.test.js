const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');

require('../src/config/env');

const { prisma } = require('../src/config/prisma');
const decimal = require('../src/utils/decimal');
const purchaseService = require('../src/services/purchase.service');
const saleService = require('../src/services/sale.service');
const stockQueryService = require('../src/services/stock-query.service');

const suffix = `${Date.now()}`;
let fixtures;

async function currentStock(productId) {
  const product = await prisma.product.findUnique({ where: { id: productId } });
  return decimal.toDecimal(product.currentStock);
}

describe('stock business rules', () => {
  before(async () => {
    const category = await prisma.category.create({
      data: { name: `TEST-CAT-${suffix}`, description: 'Données de test' },
    });
    const supplier = await prisma.supplier.create({
      data: { name: `TEST-FRN-${suffix}`, type: 'OTHER' },
    });
    const customer = await prisma.customer.create({
      data: { name: `TEST-CLI-${suffix}`, type: 'SHOP' },
    });
    const productA = await prisma.product.create({
      data: {
        sku: `TEST-A-${suffix}`,
        name: 'Produit test A',
        categoryId: category.id,
        unit: 'PACK',
        purchasePrice: '25.000',
        salePrice: '30.000',
        minimumStock: '5',
        currentStock: 0,
      },
    });
    const productB = await prisma.product.create({
      data: {
        sku: `TEST-B-${suffix}`,
        name: 'Produit test B',
        categoryId: category.id,
        unit: 'RECHARGE',
        purchasePrice: '9.500',
        salePrice: '10.000',
        minimumStock: '10',
        currentStock: 0,
      },
    });
    fixtures = { category, supplier, customer, productA, productB };
  });

  after(async () => {
    if (!fixtures) {
      await prisma.$disconnect();
      return;
    }

    const productIds = [fixtures.productA.id, fixtures.productB.id, fixtures.productC?.id].filter(Boolean);
    await prisma.stockMovement.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.purchaseItem.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.saleItem.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.productSupplier.deleteMany({ where: { productId: { in: productIds } } });
    await prisma.purchase.deleteMany({ where: { supplierId: fixtures.supplier.id } });
    await prisma.sale.deleteMany({ where: { customerId: fixtures.customer.id } });
    await prisma.product.deleteMany({ where: { id: { in: productIds } } });
    await prisma.supplier.delete({ where: { id: fixtures.supplier.id } });
    await prisma.customer.delete({ where: { id: fixtures.customer.id } });
    await prisma.category.delete({ where: { id: fixtures.category.id } });
    await prisma.$disconnect();
  });

  it('creates a purchase, increases stock and writes movements', async () => {
    const purchase = await purchaseService.createPurchase({
      supplierId: fixtures.supplier.id,
      items: [
        { productId: fixtures.productA.id, quantity: '10', unitPrice: '25.000' },
        { productId: fixtures.productB.id, quantity: '50', unitPrice: '9.500' },
      ],
    });

    assert.equal(purchase.totalAmount, '725.000');
    assert.equal(purchase.items.length, 2);
    assert.equal(decimal.toString(await currentStock(fixtures.productA.id)), '10.000');
    assert.equal(decimal.toString(await currentStock(fixtures.productB.id)), '50.000');

    const movements = await prisma.stockMovement.findMany({
      where: { referenceId: purchase.id, type: 'PURCHASE' },
    });
    assert.equal(movements.length, 2);
    fixtures.purchaseId = purchase.id;
  });

  it('creates a sale, decreases stock and writes movements', async () => {
    const sale = await saleService.createSale({
      customerId: fixtures.customer.id,
      items: [
        { productId: fixtures.productA.id, quantity: '4', unitPrice: '30.000' },
        { productId: fixtures.productB.id, quantity: '10', unitPrice: '10.000' },
      ],
    });

    assert.equal(sale.totalAmount, '220.000');
    assert.equal(decimal.toString(await currentStock(fixtures.productA.id)), '6.000');
    assert.equal(decimal.toString(await currentStock(fixtures.productB.id)), '40.000');

    const movements = await prisma.stockMovement.findMany({
      where: { referenceId: sale.id, type: 'SALE' },
    });
    assert.equal(movements.length, 2);
    fixtures.saleId = sale.id;
  });

  it('rejects a sale greater than available stock', async () => {
    await assert.rejects(
      () =>
        saleService.createSale({
          customerId: fixtures.customer.id,
          items: [{ productId: fixtures.productA.id, quantity: '100', unitPrice: '30.000' }],
        }),
      (error) => {
        assert.match(error.message, /Insufficient stock/);
        return true;
      }
    );
    assert.equal(decimal.toString(await currentStock(fixtures.productA.id)), '6.000');
  });

  it('rolls back the whole sale if one line fails', async () => {
    const beforeA = await currentStock(fixtures.productA.id);
    const beforeB = await currentStock(fixtures.productB.id);
    const salesBefore = await prisma.sale.count({ where: { customerId: fixtures.customer.id } });

    await assert.rejects(() =>
      saleService.createSale({
        customerId: fixtures.customer.id,
        items: [
          { productId: fixtures.productB.id, quantity: '1', unitPrice: '10.000' },
          { productId: fixtures.productA.id, quantity: '999', unitPrice: '30.000' },
        ],
      })
    );

    assert.equal(decimal.toString(await currentStock(fixtures.productA.id)), decimal.toString(beforeA));
    assert.equal(decimal.toString(await currentStock(fixtures.productB.id)), decimal.toString(beforeB));
    const salesAfter = await prisma.sale.count({ where: { customerId: fixtures.customer.id } });
    assert.equal(salesAfter, salesBefore);
  });

  it('adjusts stock with a mandatory reason', async () => {
    const movement = await stockQueryService.adjustStock(
      {
        productId: fixtures.productA.id,
        direction: 'in',
        quantity: '2',
        reason: 'Inventaire physique de test',
      },
      null
    );

    assert.equal(movement.type, 'ADJUSTMENT_IN');
    assert.equal(decimal.toString(await currentStock(fixtures.productA.id)), '8.000');
  });

  it('computes line and document totals with 3 decimal places', async () => {
    const purchase = await purchaseService.createPurchase({
      supplierId: fixtures.supplier.id,
      items: [{ productId: fixtures.productB.id, quantity: '3', unitPrice: '9.500' }],
    });
    assert.equal(purchase.items[0].totalPrice, '28.500');
    assert.equal(purchase.totalAmount, '28.500');
  });

  it('cancels a sale and restores stock', async () => {
    const before = await currentStock(fixtures.productA.id);
    const sale = await saleService.createSale({
      customerId: fixtures.customer.id,
      items: [{ productId: fixtures.productA.id, quantity: '1', unitPrice: '30.000' }],
    });
    await saleService.cancelSale(sale.id, null, 'Test cancellation');
    assert.equal(decimal.toString(await currentStock(fixtures.productA.id)), decimal.toString(before));
    const cancelled = await saleService.getSale(sale.id);
    assert.equal(cancelled.status, 'CANCELLED');
  });

  it('rejects purchase cancellation when stock was already sold', async () => {
    const product = await prisma.product.create({
      data: {
        sku: `TEST-C-${suffix}`,
        name: 'Produit test C',
        categoryId: fixtures.category.id,
        unit: 'PACK',
        purchasePrice: '10.000',
        salePrice: '12.000',
        minimumStock: '1',
        currentStock: 0,
      },
    });
    fixtures.productC = product;

    const purchase = await purchaseService.createPurchase({
      supplierId: fixtures.supplier.id,
      items: [{ productId: product.id, quantity: '10', unitPrice: '10.000' }],
    });
    await saleService.createSale({
      customerId: fixtures.customer.id,
      items: [{ productId: product.id, quantity: '6', unitPrice: '12.000' }],
    });

    await assert.rejects(
      () => purchaseService.cancelPurchase(purchase.id, null, 'Test'),
      (error) => {
        // Refusal, HTTP status and stable code: not the wording of the message.
        assert.equal(error.statusCode, 409);
        assert.equal(error.code, 'INSUFFICIENT_STOCK');
        return true;
      }
    );
    assert.equal(decimal.toString(await currentStock(product.id)), '4.000');
    assert.equal((await prisma.purchase.findUnique({ where: { id: purchase.id } })).status, 'CONFIRMED');
  });

  it('rejects a negative adjustment that would go below zero', async () => {
    const before = await currentStock(fixtures.productA.id);
    await assert.rejects(
      () =>
        stockQueryService.adjustStock(
          {
            productId: fixtures.productA.id,
            direction: 'out',
            quantity: '9999',
            reason: 'Test over-adjustment',
          },
          null
        ),
      (error) => {
        assert.match(error.message, /Insufficient stock/);
        return true;
      }
    );
    assert.equal(decimal.toString(await currentStock(fixtures.productA.id)), decimal.toString(before));
  });

  it('applies a negative adjustment when stock is sufficient', async () => {
    const before = await currentStock(fixtures.productA.id);
    await stockQueryService.adjustStock(
      {
        productId: fixtures.productA.id,
        direction: 'out',
        quantity: '1',
        reason: 'Produit endommage',
      },
      null
    );
    assert.equal(
      decimal.toString(await currentStock(fixtures.productA.id)),
      decimal.toString(before.minus(1))
    );
  });
});
