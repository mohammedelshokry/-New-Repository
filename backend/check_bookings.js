const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
async function main() {
    const bookings = await prisma.booking.findMany({ include: { pitch: true, user: true } });
    console.log("Bookings:", bookings.length);
    console.log(bookings);
}
main();
