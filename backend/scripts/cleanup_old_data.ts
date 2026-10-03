import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const business = await prisma.business.findFirst();
  if (!business) return;

  // 1. Delete old tables
  const validSections = ['Bahçe', 'Üst Kat', 'Loca', 'Teras'];
  
  const oldTables = await prisma.restaurantTable.findMany({
    where: {
      businessId: business.id,
      section: { notIn: validSections }
    }
  });

  for (const t of oldTables) {
    try {
      // delete orders/history if any (test data)
      const orders = await prisma.order.findMany({ where: { tableId: t.id } });
      for (const o of orders) {
        await prisma.payment.deleteMany({ where: { orderId: o.id } });
        await prisma.orderItemModifier.deleteMany({ where: { orderItem: { orderId: o.id } } });
        await prisma.orderItem.deleteMany({ where: { orderId: o.id } });
      }
      await prisma.order.deleteMany({ where: { tableId: t.id } });
      
      await prisma.restaurantTable.delete({ where: { id: t.id } });
      console.log(`Deleted old table: ${t.name} (${t.section})`);
    } catch (e: any) {
      console.error(`Could not delete table ${t.name}:`, e.message);
    }
  }

  // 2. Delete old categories
  const validCategories = [
    'Kahvaltı', 'Tostlar', 'WRAP QUESADILLA', 'Pizza', 'Tavuk Lezzetleri', 
    'Et Lezzetleri', 'Köfte Lezzetleri', 'Hamburger', 'Makarna Çeşitleri', 
    'Salata Çeşitleri', 'SALAŞ TATLI', 'ÇAYLAR', 'TÜRK KAHVESİ', 'SICAK KAHVELER', 
    'SICAK ÇİKOLATA - SAHLEP', 'SOĞUK KAHVELER', 'KOKTEYLLER', 'SOĞUK İÇECEKLER', 
    'VİTAMİN BAR', 'EĞLENCE MENÜSÜ', 'NARGİLE ÇEŞİTLERİ', 'Test Kategori'
  ];

  const oldCategories = await prisma.category.findMany({
    where: {
      businessId: business.id,
      name: { notIn: validCategories }
    }
  });

  for (const c of oldCategories) {
    try {
      const products = await prisma.product.findMany({ where: { categoryId: c.id } });
      for (const p of products) {
        const groups = await prisma.productModifierGroup.findMany({ where: { productId: p.id } });
        for (const g of groups) {
          await prisma.productModifierItem.deleteMany({ where: { modifierGroupId: g.id } });
        }
        await prisma.productModifierGroup.deleteMany({ where: { productId: p.id } });
      }
      await prisma.product.deleteMany({ where: { categoryId: c.id } });
      await prisma.category.delete({ where: { id: c.id } });
      console.log(`Deleted old category: ${c.name}`);
    } catch (e: any) {
      console.error(`Could not delete category ${c.name}:`, e.message);
    }
  }
}

main().catch(console.error).finally(() => prisma.$disconnect());
