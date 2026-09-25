import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkBookings() {
  const court = await prisma.court.findFirst({
    include: { venue: { include: { owner: true } } }
  });
  console.log('Sample court:', court?.id);

  const bookings = await prisma.booking.findMany({
    where: { courtId: court?.id },
    take: 5
  });
  console.log('Bookings on this court:', bookings.length);
  for (const b of bookings) {
    console.log('Booking:', b.id, 'startTime:', b.startTime.toISOString(), 'endTime:', b.endTime.toISOString(), 'status:', b.status);
  }
}

checkBookings().finally(() => prisma.$disconnect());
