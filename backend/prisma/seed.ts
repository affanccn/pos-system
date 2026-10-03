import { PrismaClient, Role, TableStatus } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Veritabanı tohumlama işlemi başlatılıyor...');

  await prisma.auditLog.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.restaurantTable.deleteMany();
  await prisma.product.deleteMany();
  await prisma.category.deleteMany();
  await prisma.user.deleteMany();
  await prisma.business.deleteMany();

  console.log('🧹 Eski veriler temizlendi.');

  const business = await prisma.business.create({
    data: {
      name: 'Artisan Bistro & Coffee',
      slug: 'artisan-bistro',
      currency: 'TRY',
    },
  });

  console.log(`🏢 İşletme oluşturuldu: ${business.name}`);

  const pin1111 = await bcrypt.hash('1111', 10);
  const pin2222 = await bcrypt.hash('2222', 10);
  const pin3333 = await bcrypt.hash('3333', 10);
  const pin4444 = await bcrypt.hash('4444', 10);

  const users = await prisma.$transaction([
    prisma.user.create({
      data: {
        businessId: business.id,
        fullName: 'Ahmet Patron (Owner)',
        email: 'ahmet@artisanbistro.com',
        pinCodeHash: pin1111,
        role: Role.OWNER,
      },
    }),
    prisma.user.create({
      data: {
        businessId: business.id,
        fullName: 'Mehmet Müdür (Manager)',
        email: 'mehmet@artisanbistro.com',
        pinCodeHash: pin2222,
        role: Role.MANAGER,
      },
    }),
    prisma.user.create({
      data: {
        businessId: business.id,
        fullName: 'Canan Garson (Waiter)',
        pinCodeHash: pin3333,
        role: Role.WAITER,
      },
    }),
    prisma.user.create({
      data: {
        businessId: business.id,
        fullName: 'Mutfak Ekranı (Kitchen)',
        pinCodeHash: pin4444,
        role: Role.KITCHEN,
      },
    }),
  ]);

  console.log(`👥 ${users.length} personel oluşturuldu.`);

  const tablesData = [
    { name: 'Masa 1', capacity: 2, sortOrder: 1 },
    { name: 'Masa 2', capacity: 4, sortOrder: 2 },
    { name: 'Masa 3', capacity: 4, sortOrder: 3 },
    { name: 'Masa 4', capacity: 6, sortOrder: 4 },
    { name: 'Bahçe 1', capacity: 4, sortOrder: 5 },
    { name: 'Bahçe 2', capacity: 8, sortOrder: 6 },
  ];

  await prisma.restaurantTable.createMany({
    data: tablesData.map((t) => ({
      businessId: business.id,
      name: t.name,
      capacity: t.capacity,
      status: TableStatus.AVAILABLE,
      sortOrder: t.sortOrder,
    })),
  });

  await prisma.category.create({
    data: {
      businessId: business.id,
      name: 'Sıcak Kahveler',
      sortOrder: 1,
      products: {
        create: [
          { name: 'Latte', priceCents: 13000, businessId: business.id },
          { name: 'Americano', priceCents: 11000, businessId: business.id },
          { name: 'Cappuccino', priceCents: 13500, businessId: business.id },
          { name: 'Flat White', priceCents: 14000, businessId: business.id },
        ],
      },
    },
  });

  console.log('✅ Tohumlama hazır.');
}

main()
  .catch(async (e) => {
    console.error('❌ Tohumlama hatası:', e);
    await prisma.$disconnect();
    throw e;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });