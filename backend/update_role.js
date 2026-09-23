const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  await prisma.user.updateMany({
    where: { phone: '01097967466' },
    data: { role: 'OWNER' }
  });
  console.log('Updated user to OWNER');
}
main().finally(() => prisma.$disconnect());
