-- Allow products without a SKU. Existing SKU values are preserved.
-- PostgreSQL unique indexes already allow multiple NULL values.
ALTER TABLE "products" ALTER COLUMN "sku" DROP NOT NULL;
