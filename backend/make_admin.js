const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
async function main() {
    const user = await prisma.user.update({
        where: { phone: "01097967466" },
        data: { role: "ADMIN" }
    });
    console.log("Updated user to ADMIN:", user);
}
main();
