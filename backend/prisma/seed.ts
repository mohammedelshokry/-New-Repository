import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // Clean up
  await prisma.matchRequest.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.pitch.deleteMany();
  await prisma.user.deleteMany();

  // Create Users
  const user1 = await prisma.user.create({
    data: {
      name: 'Ahmed Player',
      phone: '01011111111',
      role: 'PLAYER'
    }
  });

  const user2 = await prisma.user.create({
    data: {
      name: 'Mohamed Player',
      phone: '01022222222',
      role: 'PLAYER'
    }
  });

  const owner1 = await prisma.user.create({
    data: {
      name: 'Khaled Owner',
      phone: '01033333333',
      role: 'OWNER'
    }
  });

  // Create Pitches
  const pitchesData = [
    {
      name: 'El-Ameer Pitch',
      description: 'Top quality 5v5 football pitch with synthetic grass.',
      location: 'Nasr City, Cairo',
      surface: 'Artificial Grass',
      indoor: false,
      amenities: ['Parking', 'Changing Rooms', 'Floodlights'],
      pricePerHour: 200,
      images: ['https://images.unsplash.com/photo-1579952363873-27f3bade9f55?q=80&w=800&auto=format&fit=crop']
    },
    {
      name: 'Champions Padel Club',
      description: 'Professional padel courts with glass walls.',
      location: 'New Cairo, Cairo',
      surface: 'Blue Turf',
      indoor: false,
      amenities: ['Cafe', 'Equipment Rental', 'Showers'],
      pricePerHour: 300,
      images: ['https://images.unsplash.com/photo-1554068865-24cecd4e34f8?q=80&w=800&auto=format&fit=crop']
    },
    {
      name: 'Arena Sports Center',
      description: 'Indoor multisport arena suitable for basketball and futsal.',
      location: 'Maadi, Cairo',
      surface: 'Hardwood',
      indoor: true,
      amenities: ['AC', 'Locker Rooms', 'Stands'],
      pricePerHour: 400,
      images: ['https://images.unsplash.com/photo-1546519638-68e109498ffc?q=80&w=800&auto=format&fit=crop']
    },
    {
      name: 'Nadi El-Shams Billiards',
      description: 'Premium snooker and pool tables.',
      location: 'Heliopolis, Cairo',
      surface: 'Cloth',
      indoor: true,
      amenities: ['Cafe', 'Smoking Area', 'AC'],
      pricePerHour: 100,
      images: ['https://images.unsplash.com/photo-1574717144215-645ff12f277a?q=80&w=800&auto=format&fit=crop']
    },
    {
      name: 'PowerHouse Gym',
      description: 'Fully equipped gym with modern machines.',
      location: 'Zamalek, Cairo',
      surface: 'Rubber',
      indoor: true,
      amenities: ['Showers', 'Lockers', 'Personal Trainers'],
      pricePerHour: 150,
      images: ['https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=800&auto=format&fit=crop']
    }
  ];

  const createdPitches = [];
  for (const p of pitchesData) {
    const pitch = await prisma.pitch.create({ 
      data: {
        ...p,
        amenities: JSON.stringify(p.amenities),
        images: JSON.stringify(p.images)
      } 
    });
    createdPitches.push(pitch);
  }

  // Create some bookings for today
  const now = new Date();
  await prisma.booking.create({
    data: {
      userId: user1.id,
      pitchId: createdPitches[0].id,
      startTime: new Date(now.getFullYear(), now.getMonth(), now.getDate(), 18, 0, 0), // Today 6 PM
      endTime: new Date(now.getFullYear(), now.getMonth(), now.getDate(), 19, 0, 0), // Today 7 PM
      status: 'CONFIRMED'
    }
  });

  // Create Match Requests
  await prisma.matchRequest.create({
    data: {
      creatorId: user2.id,
      title: 'Need 2 players for 5v5',
      description: 'Looking for a goalkeeper and a defender.',
      matchTime: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 20, 0, 0), // Tomorrow 8 PM
      missingSpots: 2,
      costPerSpot: 40
    }
  });

  await prisma.matchRequest.create({
    data: {
      creatorId: user1.id,
      title: 'Padel intermediate doubles',
      description: 'Need one more player for a doubles match.',
      matchTime: new Date(now.getFullYear(), now.getMonth(), now.getDate() + 2, 19, 0, 0), 
      missingSpots: 1,
      costPerSpot: 75
    }
  });

  console.log('Seeding finished.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
