-- CreateEnum
CREATE TYPE "DocumentStatus" AS ENUM ('CONFIRMED', 'CANCELLED');

-- AlterTable
ALTER TABLE "purchases" ADD COLUMN     "cancelReason" TEXT,
ADD COLUMN     "cancelledAt" TIMESTAMP(3),
ADD COLUMN     "status" "DocumentStatus" NOT NULL DEFAULT 'CONFIRMED';

-- AlterTable
ALTER TABLE "sales" ADD COLUMN     "cancelReason" TEXT,
ADD COLUMN     "cancelledAt" TIMESTAMP(3),
ADD COLUMN     "status" "DocumentStatus" NOT NULL DEFAULT 'CONFIRMED';

-- CreateIndex
CREATE INDEX "purchases_status_idx" ON "purchases"("status");

-- CreateIndex
CREATE INDEX "sales_status_idx" ON "sales"("status");
