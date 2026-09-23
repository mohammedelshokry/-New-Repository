const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const owner = await prisma.user.findFirst({ where: { role: 'OWNER' } });
    if (!owner) throw new Error("No owner found");

    const payload = {
      name: 'Test Pitch',
      category: 'بلايستيشن',
      description: 'Test',
      location: '30.0,30.0',
      pricePerHour: 60,
      images: '[]',
      amenities: '',
      ownerId: owner.id
    };

    const pitch = await prisma.pitch.create({ data: payload });
    console.log("Success:", pitch);
  } catch (error) {
    console.error("Error creating pitch:", error);
  } finally {
    await prisma.$disconnect();
  }
}

main();
