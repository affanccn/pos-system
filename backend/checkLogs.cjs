const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
prisma.auditLog.findMany({ orderBy: { createdAt: 'desc' }, take: 10 })
  .then(logs => console.log(JSON.stringify(logs, null, 2)))
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());
