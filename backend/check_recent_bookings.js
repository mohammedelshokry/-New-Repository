const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
async function main() {
    const bookings = await prisma.booking.findMany({ orderBy: { createdAt: 'desc' }, take: 2 });
    console.log(bookings);
}
main();
