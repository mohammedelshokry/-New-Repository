import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  try {
    const court = await prisma.court.findFirst();
    console.log('Sample court:', court?.id, court?.name);

    if (!court) {
      console.log('No courts found.');
      return;
    }

    console.log('Testing tx.$executeRaw on court ID:', court.id);
    await prisma.$transaction(async (tx) => {
      try {
        const res = await tx.$executeRaw`SELECT id FROM "Court" WHERE id = ${court.id} FOR UPDATE`;
        console.log('executeRaw success, rows affected:', res);
      } catch (err: any) {
        console.error('executeRaw FAILED:', err.message);
      }

      const c = await tx.court.findUnique({ where: { id: court.id } });
      console.log('findUnique in tx result:', c?.id);
    });

    console.log('Transaction completed successfully.');
  } catch (e: any) {
    console.error('Outer error:', e.message, e.code, e.meta);
  } finally {
    await prisma.$disconnect();
  }
}

main();
