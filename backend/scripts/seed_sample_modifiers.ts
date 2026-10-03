import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding modifier groups for products...');

  // 1. Ürünleri bul
  const latte = await prisma.product.findFirst({ where: { name: 'Latte' } });
  const burger = await prisma.product.findFirst({ where: { name: { contains: 'Burger' } } });
  const cheesecake = await prisma.product.findFirst({ where: { name: { contains: 'Cheesecake' } } });

  // Latte için Süt ve Şurup Seçenekleri
  if (latte) {
    // Süt Seçimi (Tekli seçim - Zorunlu)
    const milkGroup = await prisma.productModifierGroup.create({
      data: {
        productId: latte.id,
        name: 'Süt Tercihi',
        isRequired: true,
        minSelect: 1,
        maxSelect: 1,
        sortOrder: 1,
        items: {
          create: [
            { name: 'Tam Yağlı İnek Sütü', priceCents: 0, sortOrder: 1 },
            { name: 'Yulaf Sütü', priceCents: 2000, sortOrder: 2 },
            { name: 'Badem Sütü', priceCents: 2500, sortOrder: 3 },
            { name: 'Laktozsuz Süt', priceCents: 1000, sortOrder: 4 },
          ],
        },
      },
    });
    console.log('Created milk group for Latte:', milkGroup.id);

    // Ekstra Şurup (Çoklu seçim - İsteğe bağlı)
    const syrupGroup = await prisma.productModifierGroup.create({
      data: {
        productId: latte.id,
        name: 'Ekstra Şurup & Tatlandırıcı',
        isRequired: false,
        minSelect: 0,
        maxSelect: 3,
        sortOrder: 2,
        items: {
          create: [
            { name: 'Karamel Şurubu', priceCents: 1500, sortOrder: 1 },
            { name: 'Vanilya Şurubu', priceCents: 1500, sortOrder: 2 },
            { name: 'Fındık Şurubu', priceCents: 1500, sortOrder: 3 },
            { name: 'Ekstra Espresso Shot', priceCents: 3000, sortOrder: 4 },
          ],
        },
      },
    });
    console.log('Created syrup group for Latte:', syrupGroup.id);
  }

  // Burger için Pişme Derecesi ve Ekstra Malzemeler
  if (burger) {
    const cookGroup = await prisma.productModifierGroup.create({
      data: {
        productId: burger.id,
        name: 'Et Pişme Derecesi',
        isRequired: true,
        minSelect: 1,
        maxSelect: 1,
        sortOrder: 1,
        items: {
          create: [
            { name: 'Orta Pişmiş (Medium)', priceCents: 0, sortOrder: 1 },
            { name: 'Çok Pişmiş (Well Done)', priceCents: 0, sortOrder: 2 },
            { name: 'Az Orta (Medium Rare)', priceCents: 0, sortOrder: 3 },
          ],
        },
      },
    });
    console.log('Created cook group for Burger:', cookGroup.id);

    const extraGroup = await prisma.productModifierGroup.create({
      data: {
        productId: burger.id,
        name: 'Ekstra Burger Malzemeleri',
        isRequired: false,
        minSelect: 0,
        maxSelect: 4,
        sortOrder: 2,
        items: {
          create: [
            { name: 'Ekstra Cheddar Peyniri', priceCents: 2500, sortOrder: 1 },
            { name: 'Ekstra Dana Füme', priceCents: 3500, sortOrder: 2 },
            { name: 'Karamelize Soğan', priceCents: 1500, sortOrder: 3 },
            { name: 'Jalapeno Biberi', priceCents: 1000, sortOrder: 4 },
          ],
        },
      },
    });
    console.log('Created extra group for Burger:', extraGroup.id);
  }

  // Cheesecake için Sos Seçimi
  if (cheesecake) {
    const sauceGroup = await prisma.productModifierGroup.create({
      data: {
        productId: cheesecake.id,
        name: 'Üzeri İçin Sos Seçimi',
        isRequired: false,
        minSelect: 0,
        maxSelect: 1,
        sortOrder: 1,
        items: {
          create: [
            { name: 'Sıcak Belçika Çikolatası', priceCents: 3000, sortOrder: 1 },
            { name: 'Orman Meyveli Sos', priceCents: 2500, sortOrder: 2 },
            { name: 'Karamel Sos', priceCents: 2000, sortOrder: 3 },
          ],
        },
      },
    });
    console.log('Created sauce group for Cheesecake:', sauceGroup.id);
  }

  console.log('✅ Modifiers seed completed successfully!');
}

main()
  .catch((e) => {
    console.error('Error seeding modifiers:', e);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
