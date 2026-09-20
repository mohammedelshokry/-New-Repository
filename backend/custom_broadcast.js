const admin = require('firebase-admin');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const serviceAccount = require('./firebase-admin.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

async function sendTestNotification() {
  const users = await prisma.user.findMany({ where: { fcmToken: { not: null } } });
  
  if (users.length === 0) {
    console.log("No users with FCM tokens found.");
    return;
  }

  const tokens = users.map(u => u.fcmToken);

  const message = {
    notification: {
      title: 'خصم 50% على الحجوزات! 🎉',
      body: 'افتح التطبيق الآن واحجز ملعبك المفضل بنصف السعر لفترة محدودة.',
    },
    tokens: tokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(response.successCount + ' messages were sent successfully');
    if (response.failureCount > 0) {
        console.error("Failures:", response.responses.filter(r => !r.success));
    }
  } catch (error) {
    console.log('Error sending message:', error);
  }
}

sendTestNotification();
