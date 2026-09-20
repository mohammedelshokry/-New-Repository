const { PrismaClient } = require('@prisma/client');
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const fs = require('fs');

const prisma = new PrismaClient();
const serviceAccount = JSON.parse(fs.readFileSync('./firebase-admin.json', 'utf-8'));

if (getApps().length === 0) {
  initializeApp({
    credential: cert(serviceAccount)
  });
}

async function broadcast() {
  const users = await prisma.user.findMany({ where: { fcmToken: { not: null } } });
  const tokens = users.map(u => u.fcmToken).filter(Boolean);

  const message = {
    notification: {
      title: '🌟 إشعار تجريبي عام!',
      body: 'هذا إشعار تجريبي من السيرفر لجميع الهواتف! إذا رأيت هذا فقد نجحنا 🎉',
    },
    tokens: tokens,
  };

  try {
    const response = await getMessaging().sendEachForMulticast(message);
    console.log(response.successCount + ' messages were sent successfully');
    console.log('Failures:', response.responses.filter(r => !r.success).map(r => r.error));
  } catch (error) {
    console.error('Error sending message:', error);
  } finally {
    await prisma.$disconnect();
  }
}

broadcast();
