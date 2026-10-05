import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const businesses = await prisma.business.findMany();
  console.log('Businesses:', businesses);

  const users = await prisma.user.findMany();
  console.log('Users:', users.map(u => ({ id: u.id, fullName: u.fullName, pinCodeHash: u.pinCodeHash, businessId: u.businessId })));
}

main()
  .catch(e => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
