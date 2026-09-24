// @ts-nocheck
import express, { Request, Response, NextFunction } from 'express';
import cron from 'node-cron';
import Stripe from 'stripe';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import cors from 'cors';

const prisma = new PrismaClient();
const app = express();
const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev-only';

app.use(cors({ origin: '*' }));
app.use(express.json());

declare global {
  namespace Express {
    interface Request {
      user?: { userId: string, role: string };
    }
  }
}

// Utility to add points and calculate level
async function awardGamificationPoints(userId: string, pointsToAdd: number) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) return;
  
  const newPoints = user.points + pointsToAdd;
  let newLevel = 'BRONZE';
  if (newPoints >= 5000) newLevel = 'DIAMOND';
  else if (newPoints >= 1500) newLevel = 'GOLD';
  else if (newPoints >= 500) newLevel = 'SILVER';
  
  await prisma.user.update({
    where: { id: userId },
    data: { points: newPoints, level: newLevel, matchesPlayed: user.matchesPlayed + 1 }
  });
}

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_dummy', { apiVersion: '2025-01-27.acacia' });
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import * as admin from 'firebase-admin';

try {
  const serviceAccount = require('../../firebase-admin.json');
  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  }
} catch (e) {}

// --- File Upload Setup ---
const uploadDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});
const upload = multer({ storage: storage });
app.use('/uploads', express.static(uploadDir));

// --- Auth Middleware ---
const requireAuth = (req: Request, res: Response, next: NextFunction): void => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string, role: string };
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};

const requireRole = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user || !roles.includes(req.user.role)) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    next();
  };
};

// --- Upload Route ---
app.post('/api/upload', requireAuth, upload.array('images', 5), (req: Request, res: Response): void => {
  try {
    const files = req.files as Express.Multer.File[];
    if (!files || files.length === 0) {
      res.status(400).json({ error: 'No files uploaded' });
      return;
    }
    const filePaths = files.map(file => `/uploads/${file.filename}`);
    res.json({ urls: filePaths });
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Upload failed' });
  }
});

// --- Auth Routes ---
app.post('/api/auth/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const { name, phone, password, role } = req.body;
    const existing = await prisma.user.findUnique({ where: { phone } });
    if (existing) {
      res.status(400).json({ error: 'Phone number already registered' });
      return;
    }
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: { name, phone, passwordHash, role: role || 'PLAYER' }
    });
    const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET);
    res.json({ user, token });
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Registration failed' });
  }
});

app.post('/api/auth/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { phone, password } = req.body;
    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user || !user.isActive) {
      res.status(401).json({ error: 'Invalid credentials or account suspended' });
      return;
    }
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }
    const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET);
    res.json({ user, token });
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Login failed' });
  }
});

app.get('/api/auth/me', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }
    res.json(user);
  } catch (e) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

app.put('/api/users/me', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { profilePic, name, phone, fcmToken } = req.body;
    const updateData: any = {};
    if (profilePic !== undefined) updateData.profilePic = profilePic;
    if (name !== undefined) updateData.name = name;
    if (phone !== undefined) updateData.phone = phone;
    if (fcmToken !== undefined) updateData.fcmToken = fcmToken;
    
    const user = await prisma.user.update({
      where: { id: req.user!.userId },
      data: updateData
    });
    res.json(user);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Update failed' });
  }
});

app.get('/api/users/leaderboard', async (req: Request, res: Response): Promise<void> => {
  try {
    const users = await prisma.user.findMany({
      where: { role: 'PLAYER' },
      orderBy: { points: 'desc' },
      take: 20,
      select: { id: true, name: true, points: true, level: true, matchesPlayed: true, profilePic: true }
    });
    res.json(users);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

// --- Venue Routes ---
app.get('/api/venues', async (req: Request, res: Response): Promise<void> => {
  try {
    const venues = await prisma.venue.findMany({ include: { courts: { include: { bookings: { where: { status: { in: ['CONFIRMED', 'PENDING'] } } } } }, reviews: true } });
    const parsed = venues.map((v: any) => ({
      ...v,
      images: typeof v.images === 'string' ? JSON.parse(v.images) : v.images,
    }));
    res.json(parsed);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/venues/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const venue = await prisma.venue.findUnique({
      where: { id: req.params.id },
      include: { 
        owner: { select: { name: true, phone: true } },
        courts: { include: { bookings: { where: { status: { in: ['CONFIRMED', 'PENDING'] } } } } },
        reviews: { include: { user: { select: { name: true, profilePic: true, level: true } } } }
      }
    });
    if (!venue) {
      res.status(404).json({ error: 'Venue not found' });
      return;
    }
    venue.images = typeof venue.images === 'string' ? JSON.parse(venue.images) : venue.images;
    venue.courts = venue.courts.map(c => ({
      ...c,
      images: typeof c.images === 'string' ? JSON.parse(c.images) : c.images,
      amenities: typeof c.amenities === 'string' ? JSON.parse(c.amenities) : c.amenities,
    }));
    res.json(venue);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/venues', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const payload = { ...req.body, ownerId: req.user!.userId };
    if (Array.isArray(payload.images)) payload.images = JSON.stringify(payload.images);
    
    const venue = await prisma.venue.create({ data: payload });
    res.status(201).json(venue);
  } catch (error) {
    console.error(error);
    res.status(400).json({ error: 'Invalid data' });
  }
});

app.post('/api/venues/:id/reviews', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { rating, comment } = req.body;
    const venueId = req.params.id;
    const review = await prisma.review.create({
      data: { venueId, userId: req.user!.userId, rating, comment }
    });
    const aggr = await prisma.review.aggregate({ _avg: { rating: true }, _count: { id: true }, where: { venueId } });
    await prisma.venue.update({
      where: { id: venueId },
      data: { rating: aggr._avg.rating || 0, totalReviews: aggr._count.id }
    });
    res.status(201).json(review);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Failed to add review' });
  }
});

// --- Court Routes ---
app.post('/api/venues/:id/courts', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const venueId = req.params.id;
    // verify owner
    const venue = await prisma.venue.findUnique({ where: { id: venueId } });
    if (!venue || venue.ownerId !== req.user!.userId) {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }
    const payload = { ...req.body, venueId };
    if (Array.isArray(payload.images)) payload.images = JSON.stringify(payload.images);
    if (Array.isArray(payload.amenities) || typeof payload.amenities === 'object') {
      payload.amenities = JSON.stringify(payload.amenities);
    }
    const court = await prisma.court.create({ data: payload });
    res.status(201).json(court);
  } catch (error) {
    console.error(error);
    res.status(400).json({ error: 'Invalid data' });
  }
});

app.get('/api/courts/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const court = await prisma.court.findUnique({
      where: { id: req.params.id },
      include: { venue: true, bookings: true }
    });
    if (!court) {
      res.status(404).json({ error: 'Court not found' });
      return;
    }
    court.images = typeof court.images === 'string' ? JSON.parse(court.images) : court.images;
    court.amenities = typeof court.amenities === 'string' ? JSON.parse(court.amenities) : court.amenities;
    res.json(court);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});


// --- Booking Routes ---
app.post('/api/bookings', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { courtId, startTime, endTime, isManual } = req.body;
    const sTime = new Date(startTime);
    const eTime = new Date(endTime);

    const overlap = await prisma.booking.findFirst({
      where: { courtId, status: 'CONFIRMED', OR: [ { startTime: { lt: eTime }, endTime: { gt: sTime } } ] }
    });

    if (overlap) {
      res.status(400).json({ error: 'Time slot already booked' });
      return;
    }

    const court = await prisma.court.findUnique({ where: { id: courtId }, include: { venue: { include: { owner: true } } } });
    if (!court) {
      res.status(404).json({ error: 'Court not found' });
      return;
    }

    const price = court.pricePerHour * ((eTime.getTime() - sTime.getTime()) / 3600000);
    const platformFee = price * 0.05;
    const ownerAmount = price - platformFee;

    const booking = await prisma.booking.create({
      data: {
        userId: req.user!.userId,
        courtId,
        startTime: sTime,
        status: 'CONFIRMED',
        endTime: eTime,
        price,
        platformFee,
        ownerAmount,
        isManual: isManual || false
      }
    });

    // Award Points
    await awardGamificationPoints(req.user!.userId, 50);

    // Notify Owner
    if (court.venue.owner.fcmToken) {
      try {
        await admin.messaging().send({ 
          token: court.venue.owner.fcmToken, 
          notification: { title: 'حجز جديد! ⚽', body: `تم حجز غرفة/ملعب ${court.name} بتاريخ ${sTime.toLocaleDateString()}` } 
        });
      } catch (e) {}
    }

    res.status(201).json(booking);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Failed to create booking' });
  }
});

app.get('/api/bookings', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    let whereClause = {};
    if (req.user!.role === 'OWNER') {
      whereClause = { court: { venue: { ownerId: req.user!.userId } } };
    } else {
      whereClause = { userId: req.user!.userId };
    }
    const bookings = await prisma.booking.findMany({
      where: whereClause,
      include: { court: { include: { venue: true } }, user: { select: { name: true, phone: true } } },
      orderBy: { startTime: 'desc' }
    });
    res.json(bookings);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

// Admin, Match Requests, Notifications...
// We just migrate endpoints minimally to avoid breaking

app.get('/api/match-requests', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const matches = await prisma.matchRequest.findMany({
      where: { matchTime: { gt: new Date() }, status: 'OPEN' },
      include: { creator: { select: { name: true, profilePic: true, level: true } } },
      orderBy: { matchTime: 'asc' }
    });
    res.json(matches);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/match-requests', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { title, description, matchTime, missingSpots, costPerSpot } = req.body;
    const match = await prisma.matchRequest.create({
      data: { creatorId: req.user!.userId, title, description, matchTime: new Date(matchTime), missingSpots, costPerSpot }
    });
    res.status(201).json(match);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Failed' });
  }
});

app.get('/api/admin/stats', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const totalUsers = await prisma.user.count();
    const totalVenues = await prisma.venue.count();
    const totalBookings = await prisma.booking.count();
    // Only calculate revenue for bookings that are completed/attended or confirmed
    const bookings = await prisma.booking.findMany({ where: { status: { in: ['CONFIRMED', 'ATTENDED', 'COMPLETED'] } } });
    
    // 5% commission for the admin
    const totalRevenue = bookings.reduce((sum, b) => sum + (b.price || 0), 0) * 0.05;
    
    res.json({ totalUsers, totalVenues, totalBookings, totalRevenue });
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/admin/users', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const users = await prisma.user.findMany({ 
      orderBy: { createdAt: 'desc' },
      include: {
        bookings: { include: { court: { include: { venue: true } } } },
        venues: { include: { courts: { include: { bookings: { include: { user: true } } } } } }
      }
    });
    res.json(users);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/admin/venues', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const venues = await prisma.venue.findMany({ include: { owner: true }, orderBy: { createdAt: 'desc' } });
    res.json(venues);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});


// --- Notifications ---
app.get('/api/notifications', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const notifs = await prisma.notification.findMany({
      where: { userId: req.user!.userId },
      orderBy: { createdAt: 'desc' }
    });
    res.json(notifs);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});


// --- Attendance Confirmation ---
app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id;
    const { status } = req.body;
    
    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: { court: { include: { venue: { include: { owner: true } } } }, user: true }
    });
    
    if (!booking) {
      res.status(404).json({ error: 'Booking not found' });
      return;
    }
    
    const updated = await prisma.booking.update({
      where: { id: bookingId },
      data: { status }
    });
    
    // Notifications logic
    if (status === 'REJECTED') {
      await prisma.notification.create({
        data: {
          userId: booking.userId,
          title: 'تم رفض حجزك ❌',
          body: `قام المالك بإلغاء حجزك في ${booking.court.name}. الوقت أصبح متاحاً الآن.`,
          type: 'BOOKING_REJECTED'
        }
      });
      if (booking.user.fcmToken) {
        try { await admin.messaging().send({ token: booking.user.fcmToken, notification: { title: 'تم رفض حجزك ❌', body: `قام المالك بإلغاء حجزك في ${booking.court.name}.` } }); } catch (e) {}
      }
    } else if (status === 'CANCELLED') {
      await prisma.notification.create({
        data: {
          userId: booking.court.venue.ownerId,
          title: 'إلغاء حجز من اللاعب ❌',
          body: `قام اللاعب ${booking.user.name} بإلغاء حجزه في ${booking.court.name}. الوقت أصبح متاحاً الآن.`,
          type: 'BOOKING_CANCELLED'
        }
      });
      if (booking.court.venue.owner.fcmToken) {
        try { await admin.messaging().send({ token: booking.court.venue.owner.fcmToken, notification: { title: 'إلغاء حجز من اللاعب ❌', body: `قام اللاعب ${booking.user.name} بإلغاء حجزه في ${booking.court.name}.` } }); } catch (e) {}
      }
    }
    
    res.json(updated);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/bookings/:id/confirm-attendance', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id;
    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: { court: { include: { venue: { include: { owner: true } } } }, user: true }
    });
    
    if (!booking) {
      res.status(404).json({ error: 'Booking not found' });
      return;
    }
    
    const updated = await prisma.booking.update({
      where: { id: bookingId },
      data: { status: 'ATTENDANCE_CONFIRMED' }
    });
    
    await prisma.notification.create({
      data: {
        userId: booking.court.venue.ownerId,
        title: 'تأكيد حضور اللاعب ✅',
        body: `قام اللاعب ${booking.user.name} بتأكيد حضوره لحجز ${booking.court.name} (الموعد: ${booking.startTime.toLocaleDateString()} ${booking.startTime.getHours()}:00)`,
        type: 'ATTENDANCE_CONFIRMED'
      }
    });
    
    if (booking.court.venue.owner.fcmToken) {
      try {
        await admin.messaging().send({ 
          token: booking.court.venue.owner.fcmToken, 
          notification: { title: 'تأكيد حضور اللاعب ✅', body: `قام اللاعب ${booking.user.name} بتأكيد حضوره لحجز ${booking.court.name}` } 
        });
      } catch (e) {}
    }
    
    res.json(updated);
  } catch (error) {
    console.error(error); res.status(500).json({ error: 'Server error' });
  }
});

// --- Cron Job for Reminders (Every hour) ---
cron.schedule('*/30 * * * *', async () => {
  try {
    console.log('Running attendance reminder cron job...');
    const now = new Date();
    const twoHoursFromNow = new Date(now.getTime() + 1 * 60 * 60 * 1000);
    
    // Find upcoming bookings that are CONFIRMED and within the next 2 hours
    const upcomingBookings = await prisma.booking.findMany({
      where: {
        status: 'CONFIRMED',
        startTime: {
          gt: now,
          lte: twoHoursFromNow
        }
      },
      include: { court: true, user: true }
    });
    
    for (const b of upcomingBookings) {
      await prisma.notification.create({
        data: {
          userId: b.userId,
          title: 'تأكيد الحضور ضروري ⚠️',
          body: `متبقي أقل من ساعة على حجزك في ${b.court.name}! برجاء الدخول وتأكيد الحضور الآن لضمان الحجز وعدم إلغائه.`,
          type: 'ATTENDANCE_REMINDER'
        }
      });
      
      if (b.user.fcmToken) {
        try {
          await admin.messaging().send({ 
            token: b.user.fcmToken, 
            notification: { title: 'تأكيد الحضور ضروري ⚠️', body: `متبقي أقل من ساعة على حجزك في ${b.court.name}! برجاء الدخول وتأكيد الحضور الآن لضمان الحجز وعدم إلغائه.` } 
          });
        } catch (e) {}
      }
    }
  } catch (e) {
    console.error('Cron job error:', e);
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});

export default app;
