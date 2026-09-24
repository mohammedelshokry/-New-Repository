const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const venues = await prisma.venue.findMany();
  for (let i = 0; i < venues.length; i++) {
    const lat = 30.0444 + (Math.random() * 0.1 - 0.05); // Cairo center +/-
    const lng = 31.2357 + (Math.random() * 0.1 - 0.05);
    
    await prisma.venue.update({
      where: { id: venues[i].id },
      data: { location: `${lat},${lng}` }
    });
  }
  console.log(`Updated ${venues.length} venues with map coordinates.`);
}

main().catch(console.error).finally(() => prisma.$disconnect());
