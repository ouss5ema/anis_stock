const decimal = require('./decimal');

function decimalToString(value) {
  return decimal.toString(value);
}

function stockStatus(currentStock, minimumStock) {
  if (currentStock === undefined || minimumStock === undefined) {
    return undefined;
  }
  const current = decimal.toDecimal(currentStock);
  if (current.lessThanOrEqualTo(0)) {
    return 'OUT';
  }
  if (current.lessThanOrEqualTo(decimal.toDecimal(minimumStock))) {
    return 'LOW';
  }
  return 'NORMAL';
}

function serializeUser(user) {
  if (!user) {
    return null;
  }

  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    isActive: user.isActive,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

function serializeCategory(category) {
  if (!category) {
    return null;
  }

  return {
    id: category.id,
    name: category.name,
    description: category.description,
    isActive: category.isActive,
    createdAt: category.createdAt,
    updatedAt: category.updatedAt,
    _count: category._count,
  };
}

function serializeProduct(product) {
  if (!product) {
    return null;
  }

  return {
    id: product.id,
    sku: product.sku,
    name: product.name,
    description: product.description,
    categoryId: product.categoryId,
    category: product.category ? serializeCategory(product.category) : undefined,
    unit: product.unit,
    purchasePrice: decimalToString(product.purchasePrice),
    salePrice: decimalToString(product.salePrice),
    currentStock: decimalToString(product.currentStock),
    minimumStock: decimalToString(product.minimumStock),
    estimatedValue:
      product.currentStock !== undefined && product.purchasePrice !== undefined
        ? decimalToString(decimal.multiply(product.currentStock, product.purchasePrice))
        : undefined,
    isOutOfStock:
      product.currentStock !== undefined
        ? decimal.toDecimal(product.currentStock).lessThanOrEqualTo(0)
        : undefined,
    isLowStock:
      product.currentStock !== undefined && product.minimumStock !== undefined
        ? decimal.toDecimal(product.currentStock).greaterThan(0) &&
          decimal.toDecimal(product.currentStock).lessThanOrEqualTo(decimal.toDecimal(product.minimumStock))
        : undefined,
    stockStatus: stockStatus(product.currentStock, product.minimumStock),
    isActive: product.isActive,
    createdAt: product.createdAt,
    updatedAt: product.updatedAt,
    suppliers: product.suppliers
      ? product.suppliers.map((link) => ({
          id: link.id,
          supplierId: link.supplierId,
          supplierSku: link.supplierSku,
          lastPurchasePrice: decimalToString(link.lastPurchasePrice),
          isPreferred: link.isPreferred,
          supplier: link.supplier
            ? {
                id: link.supplier.id,
                name: link.supplier.name,
                type: link.supplier.type,
              }
            : undefined,
        }))
      : undefined,
  };
}

function serializeSupplier(supplier) {
  if (!supplier) {
    return null;
  }

  return {
    id: supplier.id,
    name: supplier.name,
    type: supplier.type,
    phone: supplier.phone,
    email: supplier.email,
    address: supplier.address,
    taxNumber: supplier.taxNumber,
    notes: supplier.notes,
    isActive: supplier.isActive,
    createdAt: supplier.createdAt,
    updatedAt: supplier.updatedAt,
    stats: supplier.stats,
    products: supplier.products
      ? supplier.products.map((link) => ({
          id: link.id,
          productId: link.productId,
          supplierSku: link.supplierSku,
          lastPurchasePrice: decimalToString(link.lastPurchasePrice),
          isPreferred: link.isPreferred,
          product: link.product
            ? {
                id: link.product.id,
                sku: link.product.sku,
                name: link.product.name,
              }
            : undefined,
        }))
      : undefined,
  };
}

function serializeCustomer(customer) {
  if (!customer) {
    return null;
  }

  return {
    id: customer.id,
    name: customer.name,
    type: customer.type,
    phone: customer.phone,
    email: customer.email,
    address: customer.address,
    notes: customer.notes,
    isActive: customer.isActive,
    createdAt: customer.createdAt,
    updatedAt: customer.updatedAt,
    stats: customer.stats,
  };
}

function serializePurchaseItem(item) {
  if (!item) {
    return null;
  }

  return {
    id: item.id,
    purchaseId: item.purchaseId,
    productId: item.productId,
    product: item.product
      ? {
          id: item.product.id,
          sku: item.product.sku,
          name: item.product.name,
          unit: item.product.unit,
          currentStock: decimalToString(item.product.currentStock),
        }
      : undefined,
    quantity: decimalToString(item.quantity),
    unitPrice: decimalToString(item.unitPrice),
    totalPrice: decimalToString(item.totalPrice),
  };
}

function serializePurchase(purchase) {
  if (!purchase) {
    return null;
  }

  return {
    id: purchase.id,
    supplierId: purchase.supplierId,
    supplier: purchase.supplier,
    referenceNumber: purchase.referenceNumber,
    purchaseDate: purchase.purchaseDate,
    totalAmount: decimalToString(purchase.totalAmount),
    notes: purchase.notes,
    status: purchase.status,
    cancelledAt: purchase.cancelledAt,
    cancelReason: purchase.cancelReason,
    createdAt: purchase.createdAt,
    updatedAt: purchase.updatedAt,
    itemCount: purchase._count?.items ?? purchase.items?.length,
    items: purchase.items ? purchase.items.map(serializePurchaseItem) : undefined,
  };
}

function serializeSaleItem(item) {
  if (!item) {
    return null;
  }

  return {
    id: item.id,
    saleId: item.saleId,
    productId: item.productId,
    product: item.product
      ? {
          id: item.product.id,
          sku: item.product.sku,
          name: item.product.name,
          unit: item.product.unit,
          currentStock: decimalToString(item.product.currentStock),
        }
      : undefined,
    quantity: decimalToString(item.quantity),
    unitPrice: decimalToString(item.unitPrice),
    totalPrice: decimalToString(item.totalPrice),
  };
}

function serializeSale(sale) {
  if (!sale) {
    return null;
  }

  return {
    id: sale.id,
    customerId: sale.customerId,
    customer: sale.customer,
    referenceNumber: sale.referenceNumber,
    saleDate: sale.saleDate,
    totalAmount: decimalToString(sale.totalAmount),
    notes: sale.notes,
    status: sale.status,
    cancelledAt: sale.cancelledAt,
    cancelReason: sale.cancelReason,
    createdAt: sale.createdAt,
    updatedAt: sale.updatedAt,
    itemCount: sale._count?.items ?? sale.items?.length,
    items: sale.items ? sale.items.map(serializeSaleItem) : undefined,
  };
}

function serializeStockMovement(movement) {
  if (!movement) {
    return null;
  }

  const inbound = ['PURCHASE', 'ADJUSTMENT_IN', 'RETURN_SALE'].includes(movement.type);

  return {
    id: movement.id,
    productId: movement.productId,
    product: movement.product,
    type: movement.type,
    quantity: decimalToString(movement.quantity),
    signedQuantity: inbound
      ? decimalToString(movement.quantity)
      : `-${decimalToString(movement.quantity)}`,
    previousStock: decimalToString(movement.previousStock),
    newStock: decimalToString(movement.newStock),
    referenceType: movement.referenceType,
    referenceId: movement.referenceId,
    reason: movement.reason,
    createdAt: movement.createdAt,
    createdBy: movement.createdBy,
  };
}

module.exports = {
  decimalToString,
  serializeUser,
  serializeCategory,
  serializeProduct,
  serializeSupplier,
  serializeCustomer,
  serializePurchase,
  serializePurchaseItem,
  serializeSale,
  serializeSaleItem,
  serializeStockMovement,
};
