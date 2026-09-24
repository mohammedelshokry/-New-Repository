import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  try {
    const bookings = await prisma.booking.findMany({
      where: { court: { venue: { ownerId: "some-id" } } }
    });
    console.log("Success:", bookings.length);
  } catch (e) {
    console.error("Error:", e);
  } finally {
    await prisma.$disconnect();
  }
}
main();
