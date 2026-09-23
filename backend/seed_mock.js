const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function seed() {
  try {
    const owner = await prisma.user.findFirst({ where: { role: 'OWNER' } });
    if (!owner) {
      console.log('No owner found, skipping seed');
      return;
    }

    // Football Venue
    const footballVenue = await prisma.venue.create({
      data: {
        name: 'أكاديمية الهدف الذهبي',
        category: 'كرة قدم',
        description: 'مجمع رياضي متكامل لكرة القدم يحتوي على ملاعب خماسية وسباعية بأفضل النجيل الصناعي.',
        location: '30.0444,31.2357',
        openTime: '10:00',
        closeTime: '02:00',
        images: JSON.stringify([
          'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1518605368461-1e1e38ce8158?auto=format&fit=crop&q=80'
        ]),
        ownerId: owner.id,
      }
    });

    await prisma.court.create({
      data: {
        venueId: footballVenue.id,
        name: 'ملعب النجوم (خماسي)',
        category: 'كرة قدم',
        pricePerHour: 150,
        images: JSON.stringify(['https://images.unsplash.com/photo-1551280857-2b9bbe52042d?auto=format&fit=crop&q=80']),
        amenities: JSON.stringify({ footballSize: 'خماسي', ballIncluded: true, isAirConditioned: false }),
      }
    });

    await prisma.court.create({
      data: {
        venueId: footballVenue.id,
        name: 'الملعب الرئيسي (سباعي)',
        category: 'كرة قدم',
        pricePerHour: 250,
        images: JSON.stringify(['https://images.unsplash.com/photo-1508344928928-7165b67de128?auto=format&fit=crop&q=80']),
        amenities: JSON.stringify({ footballSize: 'سباعي', ballIncluded: true, isAirConditioned: false }),
      }
    });

    // PlayStation Venue
    const psVenue = await prisma.venue.create({
      data: {
        name: 'جيمرز لاونج - المهندسين',
        category: 'بلايستيشن',
        description: 'أفضل صالة بلايستيشن مجهزة بأحدث الشاشات وأجهزة PS5 في جو هادئ ومريح.',
        location: '30.0571,31.2001',
        openTime: '12:00',
        closeTime: '06:00',
        images: JSON.stringify([
          'https://images.unsplash.com/photo-1598550880863-4e8aa3d0edb4?auto=format&fit=crop&q=80',
          'https://images.unsplash.com/photo-1605901309584-818e25960b8f?auto=format&fit=crop&q=80'
        ]),
        ownerId: owner.id,
      }
    });

    await prisma.court.create({
      data: {
        venueId: psVenue.id,
        name: 'غرفة VIP - PS5',
        category: 'بلايستيشن',
        pricePerHour: 80,
        images: JSON.stringify(['https://images.unsplash.com/photo-1605901309584-818e25960b8f?auto=format&fit=crop&q=80']),
        amenities: JSON.stringify({ psConsole: 'PS5', psRoomType: 'VIP', isAirConditioned: true }),
      }
    });

    await prisma.court.create({
      data: {
        venueId: psVenue.id,
        name: 'غرفة عادية - PS4',
        category: 'بلايستيشن',
        pricePerHour: 40,
        images: JSON.stringify(['https://images.unsplash.com/photo-1593640408182-31c70c8268f5?auto=format&fit=crop&q=80']),
        amenities: JSON.stringify({ psConsole: 'PS4', psRoomType: 'عادية', isAirConditioned: true }),
      }
    });

    console.log('Seed completed!');
  } catch (e) {
    console.error(e);
  } finally {
    await prisma.$disconnect();
  }
}
seed();
