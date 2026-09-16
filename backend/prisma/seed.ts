import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('123456', 10);

  const admin = await prisma.user.upsert({
    where: { phone: '01000000000' },
    update: {},
    create: {
      name: 'Super Admin',
      phone: '01000000000',
      passwordHash,
      role: 'ADMIN',
    },
  });

  const owner = await prisma.user.upsert({
    where: { phone: '01098765432' },
    update: {},
    create: {
      name: 'سارة علي',
      phone: '01098765432',
      passwordHash,
      role: 'OWNER',
    },
  });

  const player = await prisma.user.upsert({
    where: { phone: '01234567890' },
    update: {},
    create: {
      name: 'محمد أحمد',
      phone: '01234567890',
      passwordHash,
      role: 'PLAYER',
    },
  });

  console.log('Database seeded successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
