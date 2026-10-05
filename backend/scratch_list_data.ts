import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const tables = await prisma.restaurantTable.findMany();
  console.log('\n--- TABLOLAR (Masalar) ---');
  tables.forEach(t => console.log(`- ${t.name} (ID: ${t.id})`));

  const categories = await prisma.category.findMany({
    include: { products: true }
  });
  console.log('\n--- KATEGORİLER VE ÜRÜNLER ---');
  categories.forEach(c => {
    console.log(`\nKategori: ${c.name} (ID: ${c.id})`);
    c.products.forEach(p => console.log(`  - Ürün: ${p.name} (ID: ${p.id})`));
  });
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
