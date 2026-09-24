const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  await prisma.notification.deleteMany({});
  await prisma.review.deleteMany({});
  await prisma.booking.deleteMany({});
  await prisma.court.deleteMany({});
  await prisma.venue.deleteMany({});
  await prisma.user.deleteMany({});

  const defaultPassword = await bcrypt.hash('123456', 10);

  console.log('Seeding ADMIN...');
  await prisma.user.create({
    data: {
      phone: '01097967466',
      passwordHash: defaultPassword,
      name: 'Mo Badawy',
      role: 'ADMIN',
      //bio: 'المطور ومدير النظام',
      profilePic: 'https://i.pravatar.cc/150?img=11',
    }
  });

  console.log('Seeding 10 Owners...');
  const owners = [];
  for (let i = 1; i <= 10; i++) {
    const owner = await prisma.user.create({
      data: {
        phone: `011000000${i.toString().padStart(2, '0')}`,
        passwordHash: defaultPassword,
        name: `Owner ${i}`,
        role: 'OWNER',
        //bio: `مدير مجمعات ${i}`,
      }
    });
    owners.push(owner);
  }

  console.log('Seeding 50 Players...');
  const players = [];
  for (let i = 1; i <= 50; i++) {
    const player = await prisma.user.create({
      data: {
        phone: `012000000${i.toString().padStart(2, '0')}`,
        passwordHash: defaultPassword,
        name: `Player ${i}`,
        role: 'PLAYER',
        //skillLevel: ['مبتدئ', 'متوسط', 'محترف'][i % 3],
      }
    });
    players.push(player);
  }

  console.log('Seeding 20 Venues & Courts...');
  const categories = ['كرة قدم', 'بادل', 'بلايستيشن', 'بلياردو', 'كرة سلة'];
  for (let i = 1; i <= 20; i++) {
    const category = categories[i % categories.length];
    const owner = owners[i % owners.length];
    
    let images = [];
    if (category === 'كرة قدم') images = ['https://images.unsplash.com/photo-1551280857-2b9bbe52042d?auto=format&fit=crop&q=80'];
    if (category === 'بلايستيشن') images = ['https://images.unsplash.com/photo-1605901309584-818e25960b8f?auto=format&fit=crop&q=80'];
    if (category === 'بادل') images = ['https://images.unsplash.com/photo-1554068865-24cecd4e34d8?auto=format&fit=crop&q=80'];

    const venue = await prisma.venue.create({
      data: {
        ownerId: owner.id,
        name: `مجمع ${category} ${i}`,
        description: `أفضل مكان لتجربة ${category} في المنطقة!`,
        location: `شارع ${i}، المدينة`,
        //latitude: 30.0 + (i * 0.01),
        //longitude: 31.0 + (i * 0.01),
        openTime: '10:00',
        closeTime: '23:00',
        images: JSON.stringify(images),
        category: category,
      }
    });

    // Add 2 courts per venue
    for (let c = 1; c <= 2; c++) {
      let amenities = { isAirConditioned: c % 2 === 0 };
      if (category === 'كرة قدم') amenities.footballSize = c % 2 === 0 ? 'خماسي' : 'سباعي';
      if (category === 'بلايستيشن') { amenities.psConsole = c % 2 === 0 ? 'PS5' : 'PS4'; amenities.psRoomType = 'عادية'; }
      if (category === 'بادل') amenities.courtType = 'زجاجي';
      
      await prisma.court.create({
        data: {
          venueId: venue.id,
          name: `غرفة/ملعب ${c}`,
          category: category,
          description: `تفاصيل الغرفة ${c}`,
          pricePerHour: 50 + (i * 10),
          images: JSON.stringify(images),
          amenities: JSON.stringify(amenities),
        }
      });
    }
  }

  console.log('Seeding done!');
}

main().catch(console.error).finally(() => prisma.$disconnect());
