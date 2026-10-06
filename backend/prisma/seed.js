const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('Admin123!', 12);
  const userPasswordHash = await bcrypt.hash('User123!', 12);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@stock.local' },
    update: {},
    create: {
      name: 'Administrateur',
      email: 'admin@stock.local',
      passwordHash,
      role: 'ADMIN',
    },
  });

  await prisma.user.upsert({
    where: { email: 'user@stock.local' },
    update: {},
    create: {
      name: 'Utilisateur démo',
      email: 'user@stock.local',
      passwordHash: userPasswordHash,
      role: 'USER',
    },
  });

  const categoryData = [
    { name: 'Tabac', description: 'Cigarettes, tabac et produits assimilés' },
    { name: 'Orange', description: 'Tickets et recharges Orange' },
    { name: 'Ooredoo', description: 'Tickets et recharges Ooredoo' },
    { name: 'Tunisie Telecom', description: 'Tickets et recharges Tunisie Telecom' },
  ];

  const categories = {};
  for (const item of categoryData) {
    const category = await prisma.category.upsert({
      where: { name: item.name },
      update: { description: item.description },
      create: item,
    });
    categories[item.name] = category;
  }

  const suppliers = await Promise.all([
    prisma.supplier.upsert({
      where: { id: '11111111-1111-1111-1111-111111111111' },
      update: {},
      create: {
        id: '11111111-1111-1111-1111-111111111111',
        name: 'Grossiste Tabac Nord',
        type: 'TABAC',
        phone: '+216 71 000 001',
        address: 'Tunis',
        notes: 'Fournisseur principal tabac',
      },
    }),
    prisma.supplier.upsert({
      where: { id: '22222222-2222-2222-2222-222222222222' },
      update: {},
      create: {
        id: '22222222-2222-2222-2222-222222222222',
        name: 'Dépôt Tabac Centre',
        type: 'TABAC',
        phone: '+216 73 000 002',
        address: 'Sousse',
      },
    }),
    prisma.supplier.upsert({
      where: { id: '33333333-3333-3333-3333-333333333333' },
      update: {},
      create: {
        id: '33333333-3333-3333-3333-333333333333',
        name: 'Distributeur Telecom Alpha',
        type: 'TELECOM',
        phone: '+216 70 000 003',
        address: 'Tunis',
      },
    }),
    prisma.supplier.upsert({
      where: { id: '44444444-4444-4444-4444-444444444444' },
      update: {},
      create: {
        id: '44444444-4444-4444-4444-444444444444',
        name: 'Distributeur Telecom Beta',
        type: 'TELECOM',
        phone: '+216 74 000 004',
        address: 'Sfax',
      },
    }),
  ]);

  const products = [
    {
      sku: 'TAB-MARL-RED',
      name: 'Marlboro Rouge',
      description: 'Paquet de cigarettes',
      categoryId: categories.Tabac.id,
      unit: 'PACK',
      purchasePrice: 7.2,
      salePrice: 8.4,
      minimumStock: 20,
      supplierIds: [suppliers[0].id, suppliers[1].id],
    },
    {
      sku: 'TAB-WINS-BLU',
      name: 'Winston Bleu',
      description: 'Paquet de cigarettes',
      categoryId: categories.Tabac.id,
      unit: 'PACK',
      purchasePrice: 6.5,
      salePrice: 7.6,
      minimumStock: 15,
      supplierIds: [suppliers[0].id],
    },
    {
      sku: 'ORG-REC-1',
      name: 'Recharge Orange 1 DT',
      description: 'Ticket recharge Orange 1 dinar',
      categoryId: categories.Orange.id,
      unit: 'RECHARGE',
      purchasePrice: 0.92,
      salePrice: 1.0,
      minimumStock: 50,
      supplierIds: [suppliers[2].id, suppliers[3].id],
    },
    {
      sku: 'ORG-REC-5',
      name: 'Recharge Orange 5 DT',
      description: 'Ticket recharge Orange 5 dinars',
      categoryId: categories.Orange.id,
      unit: 'RECHARGE',
      purchasePrice: 4.6,
      salePrice: 5.0,
      minimumStock: 30,
      supplierIds: [suppliers[2].id],
    },
    {
      sku: 'OOR-REC-1',
      name: 'Recharge Ooredoo 1 DT',
      description: 'Ticket recharge Ooredoo 1 dinar',
      categoryId: categories.Ooredoo.id,
      unit: 'RECHARGE',
      purchasePrice: 0.92,
      salePrice: 1.0,
      minimumStock: 50,
      supplierIds: [suppliers[2].id],
    },
    {
      sku: 'TT-REC-5',
      name: 'Recharge Tunisie Telecom 5 DT',
      description: 'Ticket recharge Tunisie Telecom 5 dinars',
      categoryId: categories['Tunisie Telecom'].id,
      unit: 'RECHARGE',
      purchasePrice: 4.6,
      salePrice: 5.0,
      minimumStock: 25,
      supplierIds: [suppliers[3].id],
    },
  ];

  for (const item of products) {
    const { supplierIds, ...data } = item;
    const product = await prisma.product.upsert({
      where: { sku: data.sku },
      update: {
        name: data.name,
        description: data.description,
        purchasePrice: data.purchasePrice,
        salePrice: data.salePrice,
        minimumStock: data.minimumStock,
      },
      create: data,
    });

    for (const supplierId of supplierIds) {
      await prisma.productSupplier.upsert({
        where: {
          productId_supplierId: {
            productId: product.id,
            supplierId,
          },
        },
        update: {},
        create: {
          productId: product.id,
          supplierId,
          isPreferred: supplierId === supplierIds[0],
        },
      });
    }
  }

  const customers = [
    {
      id: '55555555-5555-5555-5555-555555555555',
      name: 'FreeShop La Marsa',
      type: 'FREESHOP',
      phone: '+216 71 111 111',
      address: 'La Marsa',
    },
    {
      id: '66666666-6666-6666-6666-666666666666',
      name: 'Superette El Medina',
      type: 'SUPERMARKET',
      phone: '+216 71 222 222',
      address: 'Tunis médina',
    },
    {
      id: '77777777-7777-7777-7777-777777777777',
      name: 'Magasin Sidi Bou',
      type: 'SHOP',
      phone: '+216 71 333 333',
      address: 'Sidi Bou Saïd',
    },
  ];

  for (const customer of customers) {
    await prisma.customer.upsert({
      where: { id: customer.id },
      update: {},
      create: customer,
    });
  }

  console.log('Seed completed.');
  console.log('Admin: admin@stock.local / Admin123!');
  console.log('User:  user@stock.local / User123!');
  console.log(`Admin id: ${admin.id}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
