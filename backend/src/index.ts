// @ts-nocheck
import express, { Request, Response, NextFunction } from 'express';
import Stripe from 'stripe';


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
import * as admin from 'firebase-admin';
try {
  const serviceAccount = require('../../firebase-admin.json');
  if (!admin.apps.length) {
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  }
} catch (e) {}

import fs from 'fs';

import { PrismaClient } from '@prisma/client';
import cors from 'cors';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const prisma = new PrismaClient();
const app = express();
const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev-only';

app.use(cors({ origin: '*' }));
app.use(express.json());


declare global {
  namespace Express {
    interface Request {
      user?: { userId: string; role: string; phone: string };
    }
  }
}

const requireAuth = (req: Request, res: Response, next: NextFunction): void => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET) as any;
    req.user = payload;
    next();
  } catch (err) {
    res.status(401).json({ error: 'Invalid token' });
    return;
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

app.post('/api/upload', requireAuth, upload.array('images', 5), (req: Request, res: Response) => {
  try {
    const files = req.files as Express.Multer.File[];
    if (!files || files.length === 0) {
      // res.status(400) removed because return is needed, fixing typescript error
      res.status(400).json({ error: 'No files uploaded' });
      return;
    }
    const filePaths = files.map(file => `/uploads/${file.filename}`);
    res.json({ urls: filePaths });
  } catch (error) {
    res.status(500).json({ error: 'Upload failed' });
  }
});
// -------------------------


app.post('/api/auth/register', async (req: Request, res: Response) => {
  try {
    const { name, phone, password, role } = req.body;
    const existing = await prisma.user.findUnique({ where: { phone } });
    if (existing) return res.status(400).json({ error: 'Phone already registered' });

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: { name, phone, passwordHash, role: role || 'PLAYER' }
    });
    res.status(201).json({ message: 'User registered successfully', userId: user.id });
  } catch (error) {
    res.status(400).json({ error: 'Invalid data' });
  }
});

app.post('/api/auth/login', async (req: Request, res: Response) => {
  try {
    const { phone, password } = req.body;
    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user || !user.isActive) return res.status(401).json({ error: 'Invalid credentials' });

    const isValid = await bcrypt.compare(password, user.passwordHash);
    if (!isValid) return res.status(401).json({ error: 'Invalid credentials' });

    const token = jwt.sign({ userId: user.id, role: user.role, phone: user.phone }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, user: { id: user.id, name: user.name, role: user.role, points: user.points, level: user.level, profilePic: user.profilePic } });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/api/auth/me', requireAuth, async (req: Request, res: Response) => {
  const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json({ id: user.id, name: user.name, phone: user.phone, role: user.role, isActive: user.isActive, points: user.points, level: user.level, profilePic: user.profilePic });
});

app.put('/api/users/me', requireAuth, async (req: Request, res: Response) => {
  try {
    const { profilePic, name, phone, fcmToken } = req.body;
    
    // Only update fields that are provided
    const dataToUpdate: any = {};
    if (profilePic !== undefined) dataToUpdate.profilePic = profilePic;
    if (name !== undefined) dataToUpdate.name = name;
    if (phone !== undefined) dataToUpdate.phone = phone;
    if (fcmToken !== undefined) dataToUpdate.fcmToken = fcmToken;

    const user = await prisma.user.update({
      where: { id: req.user!.userId },
      data: dataToUpdate
    });
    res.json(user);
  } catch (e) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/pitches', async (req: Request, res: Response) => {
  try {
    const pitches = await prisma.pitch.findMany({ include: { reviews: true } });
    const parsed = pitches.map((p: any) => ({
      ...p,
      images: (typeof p.images === 'string' && p.images.startsWith('[')) ? JSON.parse(p.images) : [p.images],
      amenities: (typeof p.amenities === 'string' && p.amenities.startsWith('[')) ? JSON.parse(p.amenities) : [p.amenities]
    }));
    res.json(parsed);
  } catch (e) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/pitches/:id', async (req: Request, res: Response) => {
  try {
    const pitch = await prisma.pitch.findUnique({
      where: { id: req.params.id },
      include: { owner: { select: { name: true, phone: true } }, bookings: true, reviews: { include: { user: { select: { name: true, profilePic: true, level: true } } } } }
    }) as any;
    if (!pitch) return res.status(404).json({ error: 'Not found' });
    
    const parsed = {
      ...pitch,
      images: (typeof pitch.images === 'string' && pitch.images.startsWith('[')) ? JSON.parse(pitch.images) : [pitch.images],
      amenities: (typeof pitch.amenities === 'string' && pitch.amenities.startsWith('[')) ? JSON.parse(pitch.amenities) : [pitch.amenities]
    };
    res.json(parsed);
  } catch (e) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/pitches', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response) => {
  try {
    const payload = { ...req.body, ownerId: req.user!.userId };
    if (Array.isArray(payload.images)) payload.images = JSON.stringify(payload.images);
    if (Array.isArray(payload.amenities)) payload.amenities = JSON.stringify(payload.amenities);
    
    const pitch = await prisma.pitch.create({ data: payload });
    res.status(201).json(pitch);
  } catch (error) {
    res.status(400).json({ error: 'Invalid data' });
  }
});

app.post('/api/bookings', requireAuth, async (req: Request, res: Response) => {
  try {
    const { pitchId, startTime, endTime, isManual } = req.body;
    
    // We use a transaction with a pessimistic lock to ensure no double bookings
    const booking = await prisma.$transaction(async (tx: any) => {
      // Lock the pitch row
      await tx.$executeRawUnsafe('SELECT id FROM "Pitch" WHERE id = $1 FOR UPDATE', pitchId);
      
      const conflict = await tx.booking.findFirst({
        where: {
          pitchId,
          status: 'CONFIRMED',
          OR: [
            { startTime: { lt: new Date(endTime) }, endTime: { gt: new Date(startTime) } }
          ]
        }
      });
      
      if (conflict) throw new Error('Time slot is already booked');
      
      const pitch = await tx.pitch.findUnique({ where: { id: pitchId } });
      if (!pitch) throw new Error('Pitch not found');
      const durationHours = (new Date(endTime).getTime() - new Date(startTime).getTime()) / 3600000;
      const price = pitch.pricePerHour * durationHours;
      
      return await tx.booking.create({
        data: {
          userId: req.user!.userId,
          pitchId,
          startTime: new Date(startTime),
          endTime: new Date(endTime),
          price,
          platformFee: price * 0.05,
          ownerAmount: price * 0.95,
          isManual
        }
      });
    }, { isolationLevel: 'Serializable' });
    
    // Auto-promote logic
    if (!isManual) {
      const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
      if (user) {
        const newPoints = user.points + 50;
        let newLevel = user.level;
        if (newPoints >= 1000) newLevel = 'DIAMOND';
        else if (newPoints >= 500) newLevel = 'GOLD';
        else if (newPoints >= 200) newLevel = 'SILVER';
        
        await prisma.user.update({
          where: { id: user.id },
          data: { points: newPoints, level: newLevel, matchesPlayed: user.matchesPlayed + 1 }
        });
      }
    }
    
    try {
        const pitchData = await prisma.pitch.findUnique({ where: { id: pitchId }, include: { owner: true } });
        if (pitchData && pitchData.owner.fcmToken) {
           await admin.messaging().send({ token: pitchData.owner.fcmToken, notification: { title: 'حجز جديد! ⚽', body: `تم حجز ملعبك ${pitchData.name} بتاريخ ${new Date(startTime).toLocaleDateString()}` } });
        }
      } catch (e) {}
      res.status(201).json(booking);
  } catch (e: any) {
    res.status(400).json({ error: e.message });
  }
});

app.get('/api/bookings', requireAuth, async (req: Request, res: Response) => {
  const bookings = await prisma.booking.findMany({
    where: req.user!.role === 'OWNER' ? { pitch: { ownerId: req.user!.userId } } : { userId: req.user!.userId },
    include: { pitch: true, user: { select: { name: true, phone: true } } },
    orderBy: { createdAt: 'desc' }
  });
  res.json(bookings);
});

app.get('/api/leaderboard', async (req: Request, res: Response) => {
  try {
    const players = await prisma.user.findMany({
      where: { role: 'PLAYER' },
      orderBy: { points: 'desc' },
      take: 100,
      select: { id: true, name: true, points: true, level: true, profilePic: true }
    });
    res.json(players);
  } catch (e) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/pitches/:id/reviews', requireAuth, async (req: Request, res: Response) => {
  try {
    const { rating, comment } = req.body;
    const pitchId = req.params.id;
    
    const review = await prisma.review.create({
      data: {
        pitchId,
        userId: req.user!.userId,
        rating,
        comment
      }
    });

    const aggregations = await prisma.review.aggregate({
      where: { pitchId },
      _avg: { rating: true },
      _count: { rating: true }
    });

    await prisma.pitch.update({
      where: { id: pitchId },
      data: {
        rating: aggregations._avg.rating || 0,
        totalReviews: aggregations._count.rating || 0
      }
    });
    res.json(review);
  } catch (error) {
    res.status(400).json({ error: 'Invalid data' });
  }
});


app.get('/api/match-requests', async (req: Request, res: Response) => {
  try {
    const matches = await prisma.matchRequest.findMany({
      include: { creator: { select: { name: true, profilePic: true, level: true } } },
      orderBy: { createdAt: 'desc' }
    });
    res.json(matches);
  } catch (e) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/users/leaderboard', async (req: Request, res: Response) => {
  try {
    const users = await prisma.user.findMany({
      where: { role: 'PLAYER' },
      orderBy: { points: 'desc' },
      take: 50,
      select: { id: true, name: true, profilePic: true, points: true, level: true }
    });
    res.json(users);
  } catch (e) {
    res.status(500).json({ error: 'Server error' });
  }
});


app.get('/api/pitches/:id/leaderboard', async (req: Request, res: Response) => {
  try {
    const pitchId = req.params.id;
    const bookings = await prisma.booking.groupBy({
      by: ['userId'],
      where: { pitchId, status: 'CONFIRMED' },
      _sum: { price: true }
    });
    const userIds = bookings.map(b => b.userId).filter(Boolean) as string[];
    const users = await prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, name: true, profilePic: true, level: true }
    });
    
    const leaderboard = users.map(user => {
      const b = bookings.find(b => b.userId === user.id);
      const totalSpent = b?._sum.price || 0;
      const venuePoints = Math.floor(totalSpent * 0.5);
      return { ...user, venuePoints };
    }).sort((a, b) => b.venuePoints - a.venuePoints).slice(0, 10);
    
    res.json(leaderboard);
  } catch (e) {
    res.status(500).json({ error: 'Server error' });
  }
});

  
app.post('/api/match-requests', requireAuth, async (req: Request, res: Response) => {
  try {
    const { title, description, matchTime, missingSpots, costPerSpot } = req.body;
    const match = await prisma.matchRequest.create({
      data: {
        creatorId: req.user!.userId,
        title,
        description,
        matchTime: new Date(matchTime),
        missingSpots: Number(missingSpots),
        costPerSpot: Number(costPerSpot)
      }
    });
    res.json(match);
  } catch (e) {
    res.status(500).json({ error: 'Server error' });
  }
});

  
// Update Booking Status (Owner)
app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response) => {
  try {
    const { status } = req.body; // 'CONFIRMED' or 'REJECTED'
    const booking = await prisma.booking.findUnique({
      where: { id: req.params.id },
      include: { pitch: true }
    });
    
    if (!booking) return res.status(404).json({ error: 'Booking not found' });
    
    // Verify owner
    if (booking.pitch.ownerId !== req.user!.userId) {
      return res.status(403).json({ error: 'Unauthorized' });
    }
    
    const updated = await prisma.booking.update({
      where: { id: booking.id },
      data: { status }
    });
    
    // Notify User
    let title = '';
    let body = '';
    if (status === 'CONFIRMED') {
      title = 'تم تأكيد حجزك';
      body = `قام المالك بتأكيد حجزك في ملعب ${booking.pitch.name}`;
    } else {
      title = 'تم رفض حجزك';
      body = `نأسف، قام المالك برفض طلب حجزك في ملعب ${booking.pitch.name}`;
    }
    
    await prisma.notification.create({
      data: {
        userId: booking.userId,
        title,
        body,
        type: 'BOOKING_UPDATE'
      }
    });
    
    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

// Get Notifications
app.get('/api/notifications', requireAuth, async (req: Request, res: Response) => {
  try {
    const notifs = await prisma.notification.findMany({
      where: { userId: req.user!.userId },
      orderBy: { createdAt: 'desc' }
    });
    res.json(notifs);
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

// Mark Notifications as Read
app.patch('/api/notifications/read-all', requireAuth, async (req: Request, res: Response) => {
  try {
    await prisma.notification.updateMany({
      where: { userId: req.user!.userId, isRead: false },
      data: { isRead: true }
    });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});


// ==========================================
// PHASE 4: Community & MatchRequest Engine
// ==========================================

// Get all open match requests
app.get('/api/matches', requireAuth, async (req: Request, res: Response) => {
  try {
    const matches = await prisma.matchRequest.findMany({
      where: { status: 'OPEN' },
      include: {
        creator: {
          select: { id: true, name: true, level: true, points: true, profilePic: true }
        }
      },
      orderBy: { matchTime: 'asc' }
    });
    res.json(matches);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch match requests' });
  }
});

// Create a new match request
app.post('/api/matches', requireAuth, async (req: Request, res: Response) => {
  try {
    const { title, description, matchTime, missingSpots, costPerSpot } = req.body;
    const match = await prisma.matchRequest.create({
      data: {
        creatorId: req.user!.userId,
        title,
        description,
        matchTime: new Date(matchTime),
        missingSpots: parseInt(missingSpots),
        costPerSpot: parseFloat(costPerSpot)
      }
    });
    res.json(match);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create match request' });
  }
});

// Get messages for a match (Chat Phase)
app.get('/api/matches/:id/messages', requireAuth, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const messages = await prisma.message.findMany({
      where: { matchRequestId: id },
      include: {
        sender: {
          select: { id: true, name: true, profilePic: true, level: true }
        }
      },
      orderBy: { createdAt: 'asc' }
    });
    res.json(messages);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

// Send a message in a match
app.post('/api/matches/:id/messages', requireAuth, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { content } = req.body;
    const message = await prisma.message.create({
      data: {
        matchRequestId: id,
        senderId: req.user!.userId,
        content
      }
    });
    res.json(message);
  } catch (error) {
    res.status(500).json({ error: 'Failed to send message' });
  }
});


// ==========================================
// PHASE 5: Payments & Gamification
// ==========================================

// 1. Create Checkout Session for a Booking

// Owner Confirm Cash Payment
app.post('/api/bookings/:id/confirm-cash', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response) => {
  try {
    const booking = await prisma.booking.findUnique({ where: { id: req.params.id }, include: { pitch: true } });
    if (!booking) return res.status(404).json({ error: 'Not found' });
    if (booking.pitch.ownerId !== req.user!.userId) return res.status(403).json({ error: 'Unauthorized' });
    if (booking.paymentStatus === 'PAID') return res.status(400).json({ error: 'Already paid' });

    const updated = await prisma.booking.update({
      where: { id: booking.id },
      data: { paymentStatus: 'PAID', status: 'COMPLETED' }
    });

    // Award points
    await awardGamificationPoints(booking.userId, 100);

    res.json(updated);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Player Confirm Attendance
app.post('/api/bookings/:id/confirm-attendance', requireAuth, async (req: Request, res: Response) => {
  try {
    const booking = await prisma.booking.findUnique({ where: { id: req.params.id } });
    if (!booking) return res.status(404).json({ error: 'Not found' });
    if (booking.userId !== req.user!.userId) return res.status(403).json({ error: 'Unauthorized' });

    const updated = await prisma.booking.update({
      where: { id: booking.id },
      data: { status: 'ATTENDANCE_CONFIRMED' }
    });

    res.json(updated);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// Cron job to auto-complete and award points if time passed (Runs every 15 mins)
setInterval(async () => {
  try {
    const now = new Date();
    // Safety check if Prisma is disconnected due to sleep
    const passedBookings = await prisma.booking.findMany({
      where: {
        endTime: { lt: now },
        status: { in: ['CONFIRMED', 'ATTENDANCE_CONFIRMED'] },
        paymentStatus: 'UNPAID'
      }
    });

    for (const b of passedBookings) {
      await prisma.booking.update({
        where: { id: b.id },
        data: { status: 'COMPLETED' }
      });
      await awardGamificationPoints(b.userId, 100);
    }
  } catch (e: any) {
    console.error('Cron Error safely caught:', e.message || e);
  }
}, 15 * 60 * 1000);

app.post('/api/bookings/:id/pay', requireAuth, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const booking = await prisma.booking.findUnique({
      where: { id },
      include: { pitch: true }
    });

    if (!booking) return res.status(404).json({ error: 'Booking not found' });
    if (booking.userId !== req.user!.userId) return res.status(403).json({ error: 'Unauthorized' });
    if (booking.paymentStatus === 'PAID') return res.status(400).json({ error: 'Already paid' });

    // Phase 5: Simulated Stripe Checkout if using dummy key
    if (process.env.STRIPE_SECRET_KEY === undefined || process.env.STRIPE_SECRET_KEY === 'sk_test_dummy') {
      // Simulate success for local testing without valid keys
      await prisma.booking.update({ where: { id: booking.id }, data: { paymentStatus: 'PAID' } });
      await awardGamificationPoints(booking.userId, 100);
      return res.json({ url: 'https://spotaia.com/payment/success?session_id=simulated', sessionId: 'simulated' });
    }

    // Create Stripe Checkout Session
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency: 'egp',
          product_data: {
            name: `حجز ملعب: ${booking.pitch.name}`,
            description: `تاريخ الحجز: ${booking.startTime.toLocaleString()}`
          },
          unit_amount: Math.round(booking.price * 100), // Stripe expects cents/piasters
        },
        quantity: 1,
      }],
      mode: 'payment',
      success_url: `https://spotaia.com/payment/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `https://spotaia.com/payment/cancel`,
      client_reference_id: booking.id,
      metadata: { bookingId: booking.id }
    });

    res.json({ url: session.url, sessionId: session.id });
  } catch (error) {
    console.error('Payment Error:', error);
    res.status(500).json({ error: 'Failed to initiate payment' });
  }
});

// 2. Stripe Webhook to update payment status
app.post('/api/webhooks/stripe', express.raw({ type: 'application/json' }), async (req: Request, res: Response) => {
  const sig = req.headers['stripe-signature'] as string;
  let event;
  
  try {
    // In production, use your actual webhook secret
    const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET || 'whsec_dummy';
    event = stripe.webhooks.constructEvent(req.body, sig, endpointSecret);
  } catch (err: any) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as any;
    const bookingId = session.metadata?.bookingId;
    if (bookingId) {
      const updatedBooking = await prisma.booking.update({
        where: { id: bookingId },
        data: { paymentStatus: 'PAID' }
      });
      await awardGamificationPoints(updatedBooking.userId, 100);
    }
  }
  res.json({ received: true });
});


// --- Admin Dashboard Routes ---
app.get('/api/admin/stats', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response) => {
  try {
    const totalUsers = await prisma.user.count();
    const totalPitches = await prisma.pitch.count();
    const totalBookings = await prisma.booking.count();
    const bookings = await prisma.booking.findMany({ where: { status: 'CONFIRMED' } });
    const totalRevenue = bookings.reduce((sum, b) => sum + (b.totalPrice || 0), 0);
    res.json({ totalUsers, totalPitches, totalBookings, totalRevenue });
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/admin/users', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response) => {
  try {
    const users = await prisma.user.findMany({ orderBy: { createdAt: 'desc' } });
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/admin/pitches', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response) => {
  try {
    const pitches = await prisma.pitch.findMany({ include: { owner: true }, orderBy: { createdAt: 'desc' } });
    res.json(pitches);
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});


app.delete('/api/admin/pitches/:id', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response) => {
  try {
    // Delete pitch related data first or use cascade in prisma, let's assume cascade is not there
    await prisma.review.deleteMany({ where: { pitchId: req.params.id } });
    await prisma.booking.deleteMany({ where: { pitchId: req.params.id } });
    await prisma.pitch.delete({ where: { id: req.params.id } });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/admin/users/:id/toggle-ban', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.params.id } });
    if (!user) return res.status(404).json({ error: 'User not found' });
    const updated = await prisma.user.update({
      where: { id: req.params.id },
      data: { isActive: !user.isActive }
    });
    res.json(updated);
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});


app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});

export default app;

