const { prisma } = require('../config/prisma');

/**
 * Records a sensitive action. Call it with the transaction client `tx` so the
 * audit entry is committed (or rolled back) together with the action itself.
 */
async function record(client, { action, entityType, entityId, entityLabel, reason, metadata, userId }) {
  return (client || prisma).auditLog.create({
    data: {
      action,
      entityType,
      entityId,
      entityLabel: entityLabel ?? null,
      reason: reason ?? null,
      metadata: metadata ?? undefined,
      userId: userId ?? null,
    },
  });
}

/**
 * Summarizes applyMovement results per product (first stock before, last stock
 * after), human readable for the audit metadata.
 */
function stockChanges(results) {
  const byProduct = new Map();
  for (const { product, previousStock, newStock } of results) {
    const entry = byProduct.get(product.id);
    if (entry) {
      entry.stockAfter = newStock.toFixed(3);
    } else {
      byProduct.set(product.id, {
        productId: product.id,
        productName: product.name,
        stockBefore: previousStock.toFixed(3),
        stockAfter: newStock.toFixed(3),
      });
    }
  }
  return [...byProduct.values()];
}

function describeLines(items) {
  return items.map((item) => ({
    productId: item.productId,
    productName: item.product?.name,
    quantity: String(item.quantity),
    unitPrice: String(item.unitPrice),
  }));
}

module.exports = { record, stockChanges, describeLines };
