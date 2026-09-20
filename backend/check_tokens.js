const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
async function main() {
    const users = await prisma.user.findMany({
        where: { fcmToken: { not: null } }
    });
    console.log("Users with FCM tokens:", users.map(u => ({ name: u.name, fcmToken: u.fcmToken })));
}
main();
