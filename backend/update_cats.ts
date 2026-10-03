import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
async function main() {
  await prisma.category.updateMany({
    where: { name: 'Sıcak Kahveler' },
    data: { stationType: 'COFFEE' }
  });
  await prisma.category.updateMany({
    where: { name: 'Soğuk İçecekler' },
    data: { stationType: 'BAR' }
  });
  await prisma.category.updateMany({
    where: { name: 'Tatlılar & Fırın' },
    data: { stationType: 'DESSERT' }
  });
  console.log("Updated categories");
}
main().finally(() => prisma.$disconnect());
