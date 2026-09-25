const path = require('path');
const backendDir = path.resolve(__dirname, '../../../backend');
const { PrismaClient } = require(path.join(backendDir, 'node_modules/@prisma/client'));
const prisma = new PrismaClient();

async function check() {
  const users = await prisma.user.count();
  const venues = await prisma.venue.count();
  const courts = await prisma.court.count();
  const bookings = await prisma.booking.count();
  const matches = await prisma.matchRequest.count();
  const messages = await prisma.message.count();
  const notifications = await prisma.notification.count();
  const reviews = await prisma.review.count();

  console.log(JSON.stringify({
    users,
    venues,
    courts,
    bookings,
    matches,
    messages,
    notifications,
    reviews
  }, null, 2));

  await prisma.$disconnect();
}

check().catch(console.error);
