const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
async function main() {
    const users = await prisma.user.findMany({ where: { fcmToken: { not: null } } });
    console.log("Tokens found:", users.length);
    console.log(users.map(u => u.fcmToken));
}
main();
