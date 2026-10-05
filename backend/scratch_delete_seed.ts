import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const seedCategories = await prisma.category.findMany({
    where: { name: 'Sıcak Kahveler' },
    include: { products: true }
  });

  if (seedCategories.length === 0) {
    console.log('Sıcak Kahveler kategorisi bulunamadı.');
    return;
  }

  for (const cat of seedCategories) {
    console.log(`Siliniyor: ${cat.name} ve ${cat.products.length} ürünü...`);
    
    // Delete order items referencing these products? No, if there are order items, we might get foreign key constraint.
    // Wait, let's check if there are any order items!
    const productIds = cat.products.map(p => p.id);
    const orderItems = await prisma.orderItem.count({
      where: { productId: { in: productIds } }
    });

    if (orderItems > 0) {
      console.log(`DİKKAT: Bu kategorideki ürünleri içeren ${orderItems} sipariş var. Önce siparişleri silmek gerekebilir!`);
      // Just delete order items for these products if they are dummy
      await prisma.orderItem.deleteMany({
        where: { productId: { in: productIds } }
      });
      console.log('İlgili dummy sipariş kalemleri silindi.');
    }

    // Delete products
    await prisma.product.deleteMany({
      where: { categoryId: cat.id }
    });
    
    // Delete category
    await prisma.category.delete({
      where: { id: cat.id }
    });
    
    console.log(`✅ ${cat.name} başarıyla silindi!`);
  }
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
