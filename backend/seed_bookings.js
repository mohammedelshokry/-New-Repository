const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const players = await prisma.user.findMany({ where: { role: 'PLAYER' } });
  const courts = await prisma.court.findMany();

  if (players.length === 0 || courts.length === 0) return;

  console.log('Generating 150 fake bookings...');
  
  const now = new Date();
  for (let i = 0; i < 150; i++) {
    const player = players[Math.floor(Math.random() * players.length)];
    const court = courts[Math.floor(Math.random() * courts.length)];

    const pastDays = Math.floor(Math.random() * 30) + 1;
    const hour = Math.floor(Math.random() * 12) + 10;
    
    // Construct valid Date objects
    const startTime = new Date(now.getTime() - (pastDays * 24 * 60 * 60 * 1000));
    startTime.setHours(hour, 0, 0, 0);
    
    const endTime = new Date(startTime.getTime());
    endTime.setHours(hour + 1, 0, 0, 0);

    const price = court.pricePerHour;
    const platformFee = price * 0.05;
    const ownerAmount = price * 0.95;

    await prisma.booking.create({
      data: {
        userId: player.id,
        courtId: court.id,
        startTime: startTime,
        endTime: endTime,
        price: price,
        platformFee: platformFee,
        ownerAmount: ownerAmount,
        status: 'COMPLETED',
        paymentStatus: 'PAID',
      }
    });
  }

  console.log('Bookings seeded successfully!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
