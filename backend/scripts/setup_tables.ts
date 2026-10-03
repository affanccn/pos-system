import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const business = await prisma.business.findFirst();
  if (!business) {
    console.error('No business found');
    return;
  }

  // 1. Fix duplicated categories
  console.log('Fixing duplicate categories...');
  const categories = await prisma.category.findMany({
    where: { businessId: business.id },
    orderBy: { createdAt: 'desc' },
  });

  const seenNames = new Set<string>();
  for (const cat of categories) {
    if (seenNames.has(cat.name)) {
      console.log(`Found duplicate category: ${cat.name}. Deleting older one...`);
      // Delete products and their modifiers
      const products = await prisma.product.findMany({ where: { categoryId: cat.id } });
      for (const p of products) {
        const groups = await prisma.productModifierGroup.findMany({ where: { productId: p.id } });
        for (const g of groups) {
          await prisma.productModifierItem.deleteMany({ where: { modifierGroupId: g.id } });
        }
        await prisma.productModifierGroup.deleteMany({ where: { productId: p.id } });
      }
      await prisma.product.deleteMany({ where: { categoryId: cat.id } });
      await prisma.category.delete({ where: { id: cat.id } });
      console.log(`Deleted duplicate category: ${cat.name}`);
    } else {
      seenNames.add(cat.name);
    }
  }

  // 2. Setup Tables
  console.log('Setting up tables...');
  
  const sections = [
    { name: 'Bahçe', count: 30, prefix: 'Bahçe' },
    { name: 'Üst Kat', count: 8, prefix: 'Üst Kat' },
    { name: 'Loca', count: 4, prefix: 'Loca' },
    { name: 'Teras', count: 20, prefix: 'Teras' },
  ];

  for (let i = 0; i < sections.length; i++) {
    const s = sections[i];

    // Create tables
    for (let j = 1; j <= s.count; j++) {
      const tableName = `${s.prefix} ${j}`;
      const existing = await prisma.restaurantTable.findUnique({
        where: {
          businessId_name: {
            businessId: business.id,
            name: tableName,
          }
        }
      });

      if (existing) {
        await prisma.restaurantTable.update({
          where: { id: existing.id },
          data: {
            section: s.name,
            sortOrder: j,
          }
        });
      } else {
        await prisma.restaurantTable.create({
          data: {
            businessId: business.id,
            name: tableName,
            section: s.name,
            status: 'AVAILABLE',
            sortOrder: j,
          }
        });
      }
    }
    console.log(`Created/Updated ${s.count} tables for ${s.name}`);
  }

  // Delete any tables that are NOT in these sections to keep it clean (optional, skipping to be safe)

  console.log('Done!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
