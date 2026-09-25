import 'dotenv/config';
import express, { Request, Response, NextFunction } from 'express';
import cron from 'node-cron';
import Stripe from 'stripe';
import { PrismaClient, Prisma } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import cors from 'cors';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { initializeApp, cert, getApps, App } from 'firebase-admin/app';
import { getMessaging, Messaging, Message } from 'firebase-admin/messaging';

const prisma = new PrismaClient();
const app = express();
const PORT = Number(process.env.PORT) || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev-only';
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_dummy', { apiVersion: '2026-08-26.dahlia' });

app.use(cors({ origin: '*' }));
app.use(express.json());

declare global {
  namespace Express {
    interface Request {
      user?: { userId: string; role: string };
    }
  }
}

// --- Sanitization Utilities ---
function sanitizeUser<T extends { passwordHash?: string }>(user: T): Omit<T, 'passwordHash'> {
  if (!user) return user;
  const { passwordHash, ...safe } = user;
  return safe;
}

function sanitizeUsers<T extends { passwordHash?: string }>(users: T[]): Omit<T, 'passwordHash'>[] {
  return users.map(sanitizeUser);
}

// --- Firebase Admin v14 Modular SDK & Push Notifications ---
let appInstance: App | null = null;
let messagingInstance: Messaging | null = null;

function getFirebaseMessaging(): Messaging | null {
  if (messagingInstance) return messagingInstance;
  if (getApps().length > 0) {
    appInstance = getApps()[0];
    messagingInstance = getMessaging(appInstance);
    return messagingInstance;
  }

  const candidatePaths = [
    path.resolve(process.cwd(), 'firebase-admin.json'),
    path.resolve(process.cwd(), 'backend', 'firebase-admin.json'),
    path.join(__dirname, '..', 'firebase-admin.json'),
    path.join(__dirname, '..', '..', 'firebase-admin.json')
  ];

  let credentialPath: string | null = null;
  for (const p of candidatePaths) {
    if (fs.existsSync(p)) {
      credentialPath = p;
      break;
    }
  }

  if (!credentialPath) {
    console.warn('[Firebase] Warning: firebase-admin.json not found. Push notifications will be skipped.');
    return null;
  }

  try {
    const serviceAccount = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
    appInstance = initializeApp({ credential: cert(serviceAccount) });
    messagingInstance = getMessaging(appInstance);
    console.log('[Firebase] Initialized with credentials from:', credentialPath);
    return messagingInstance;
  } catch (err) {
    console.error('[Firebase] Initialization error:', err);
    return null;
  }
}

async function sendPushNotification(
  token: string | null | undefined,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<boolean> {
  if (!token) return false;
  const messaging = getFirebaseMessaging();
  if (!messaging) return false;

  try {
    const message: Message = {
      token,
      notification: { title, body },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'spotaia_channel',
        },
      },
    };
    await messaging.send(message);
    return true;
  } catch (error: any) {
    console.warn(`[Firebase] Failed to send push notification (${error?.code || error?.message || 'unknown error'})`);
    return false;
  }
}

// --- Gamification Helper ---
async function awardGamificationPoints(userId: string, pointsToAdd: number): Promise<void> {
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

// --- Multer File Upload Security & Storage Setup ---
const uploadDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: function (_req, _file, cb) {
    cb(null, uploadDir);
  },
  filename: function (_req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, uniqueSuffix + ext);
  }
});

const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp']);
const ALLOWED_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp']);

const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB limit
    files: 5                   // max 5 files
  },
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (ALLOWED_MIME_TYPES.has(file.mimetype) && ALLOWED_EXTENSIONS.has(ext)) {
      cb(null, true);
    } else {
      cb(new Error('الملف المرفوع يجب أن يكون صورة بصيغة (JPEG, PNG, WebP) فقط'));
    }
  }
});

app.use('/uploads', express.static(uploadDir));

// --- Auth Middlewares ---
const requireAuth = (req: Request, res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.startsWith('Bearer ') ? authHeader.split(' ')[1] : authHeader;
  if (!token) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string; role: string };
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
app.post('/api/upload', requireAuth, (req: Request, res: Response): void => {
  upload.array('images', 5)(req, res, (err: any) => {
    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        res.status(400).json({ error: 'حجم الصورة يجب ألا يتجاوز 5 ميجابايت' });
        return;
      }
      if (err.code === 'LIMIT_FILE_COUNT' || err.code === 'LIMIT_UNEXPECTED_FILE') {
        res.status(400).json({ error: 'الحد الأقصى المسموح به هو 5 صور' });
        return;
      }
      res.status(400).json({ error: `خطأ في رفع الملفات: ${err.message}` });
      return;
    } else if (err) {
      res.status(400).json({ error: err.message || 'فشل في رفع الملف' });
      return;
    }
    const files = req.files as Express.Multer.File[];
    if (!files || files.length === 0) {
      res.status(400).json({ error: 'No files uploaded' });
      return;
    }
    const filePaths = files.map((file) => `/uploads/${file.filename}`);
    res.json({ urls: filePaths });
  });
});

// --- Auth Routes ---
app.post('/api/auth/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const { name, phone, password, role } = req.body;
    if (!name || !phone || !password) {
      res.status(400).json({ error: 'Name, phone and password are required' });
      return;
    }

    // Security Guard: Prohibit unauthenticated callers from self-elevating to ADMIN
    if (role === 'ADMIN') {
      res.status(403).json({ error: 'غير مسموح بإنشاء حساب مسؤول من واجهة التسجيل العامة' });
      return;
    }

    const existing = await prisma.user.findUnique({ where: { phone } });
    if (existing) {
      res.status(400).json({ error: 'Phone number already registered' });
      return;
    }

    const userRole = (role === 'OWNER') ? 'OWNER' : 'PLAYER';
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: { name, phone, passwordHash, role: userRole }
    });
    const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });

    res.status(201).json({ user: sanitizeUser(user), token });
  } catch (error) {
    console.error('Registration failed:', error);
    res.status(500).json({ error: 'Registration failed' });
  }
});

app.post('/api/auth/login', async (req: Request, res: Response): Promise<void> => {
  try {
    const { phone, password } = req.body;
    if (!phone || !password) {
      res.status(400).json({ error: 'Phone and password are required' });
      return;
    }

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

    const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ user: sanitizeUser(user), token });
  } catch (error) {
    console.error('Login failed:', error);
    res.status(500).json({ error: 'Login failed' });
  }
});

app.get('/api/auth/me', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }
    res.json(sanitizeUser(user));
  } catch (e) {
    console.error('Auth /me error:', e);
    res.status(500).json({ error: 'Server error' });
  }
});

// --- User Profile & Gamification Routes ---
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
    res.json(sanitizeUser(user));
  } catch (error) {
    console.error('Update user profile failed:', error);
    res.status(500).json({ error: 'Update failed' });
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
    console.error('Leaderboard fetch failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// --- Venue Routes ---
app.get('/api/venues', async (req: Request, res: Response): Promise<void> => {
  try {
    const venues = await prisma.venue.findMany({
      include: {
        courts: {
          include: {
            bookings: {
              where: { status: { in: ['CONFIRMED', 'PENDING', 'ATTENDANCE_CONFIRMED'] } }
            }
          }
        },
        reviews: true
      }
    });

    const parsed = venues.map((v: any) => ({
      ...v,
      images: typeof v.images === 'string' ? (v.images.startsWith('[') || v.images.startsWith('{') ? JSON.parse(v.images) : [v.images]) : v.images,
    }));
    res.json(parsed);
  } catch (error) {
    console.error('Get venues failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/venues/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const venueId = req.params.id as string;
    const venue = await prisma.venue.findUnique({
      where: { id: venueId },
      include: { 
        owner: { select: { id: true, name: true, phone: true } },
        courts: {
          include: {
            bookings: {
              where: { status: { in: ['CONFIRMED', 'PENDING', 'ATTENDANCE_CONFIRMED'] } }
            }
          }
        },
        reviews: {
          include: {
            user: { select: { id: true, name: true, profilePic: true, level: true } }
          }
        }
      }
    });

    if (!venue) {
      res.status(404).json({ error: 'Venue not found' });
      return;
    }

    const venueImages = typeof venue.images === 'string'
      ? (venue.images.startsWith('[') || venue.images.startsWith('{') ? JSON.parse(venue.images) : [venue.images])
      : venue.images;

    const formattedCourts = venue.courts.map((c) => ({
      ...c,
      images: typeof c.images === 'string'
        ? (c.images.startsWith('[') || c.images.startsWith('{') ? JSON.parse(c.images) : [c.images])
        : c.images,
      amenities: typeof c.amenities === 'string'
        ? (c.amenities.startsWith('[') || c.amenities.startsWith('{') ? JSON.parse(c.amenities) : c.amenities)
        : c.amenities,
    }));

    res.json({
      ...venue,
      images: venueImages,
      courts: formattedCourts,
    });
  } catch (error) {
    console.error('Get venue by id failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});


app.patch('/api/venues/:id', requireAuth, upload.array('images', 5), async (req: Request, res: Response): Promise<void> => {
  try {
    const venueId = req.params.id as string;
    const name = req.body.name as string | undefined;
    const description = req.body.description as string | undefined;
    const category = req.body.category as string | undefined;
    const location = req.body.location as string | undefined;
    const openTime = req.body.openTime as string | undefined;
    const closeTime = req.body.closeTime as string | undefined;
    
    const venue = await prisma.venue.findUnique({ where: { id: venueId } });
    if (!venue) { res.status(404).json({ error: 'Venue not found' }); return; }
    if (venue.ownerId !== req.user!.userId) { res.status(403).json({ error: 'Unauthorized' }); return; }

    const files = req.files as Express.Multer.File[];
    let imagesArr: string[] = [];
    if (venue.images) {
      try { imagesArr = JSON.parse(venue.images); } catch(e) {}
    }
    
    if (req.body.existingImages) {
      try { imagesArr = JSON.parse(req.body.existingImages as string); } catch(e) {}
    }

    if (files && files.length > 0) {
      const newImages = files.map(f => '/uploads/' + f.filename);
      imagesArr = [...imagesArr, ...newImages];
    }

    const updated = await prisma.venue.update({
      where: { id: venueId },
      data: {
        name, description, category, location, openTime, closeTime,
        images: JSON.stringify(imagesArr)
      }

    });
    res.json(updated);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/venues', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const payload = { ...req.body, ownerId: req.user!.userId };
    if (Array.isArray(payload.images)) payload.images = JSON.stringify(payload.images);
    
    const venue = await prisma.venue.create({ data: payload });
    res.status(201).json(venue);
  } catch (error) {
    console.error('Create venue failed:', error);
    res.status(400).json({ error: 'Invalid data' });
  }
});

app.post('/api/venues/:id/reviews', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { rating, comment } = req.body;
    const venueId = req.params.id as string;
    const review = await prisma.review.create({
      data: { venueId, userId: req.user!.userId, rating, comment }
    });
    const aggr = await prisma.review.aggregate({ _avg: { rating: true }, _count: { id: true }, where: { venueId } });
    await prisma.venue.update({
      where: { id: venueId },
      data: { rating: aggr._avg.rating || 0, totalReviews: aggr._count?.id || 0 }
    });
    res.status(201).json(review);
  } catch (error) {
    console.error('Create review failed:', error);
    res.status(500).json({ error: 'Failed to add review' });
  }
});

// --- Venue Leaderboard ---
app.get('/api/venues/:id/leaderboard', async (req: Request, res: Response): Promise<void> => {
  try {
    const venueId = req.params.id as string;
    if (!venueId) {
      res.status(400).json({ error: 'Venue ID is required' });
      return;
    }

    const venue = await prisma.venue.findUnique({
      where: { id: venueId },
      select: { id: true }
    });

    if (!venue) {
      res.status(404).json({ error: 'Venue not found' });
      return;
    }

    const bookings = await prisma.booking.findMany({
      where: {
        court: { venueId },
        status: { in: ['CONFIRMED', 'ATTENDANCE_CONFIRMED', 'ATTENDED', 'COMPLETED'] },
      },
      select: {
        userId: true,
        user: {
          select: {
            id: true,
            name: true,
            points: true,
            level: true,
            matchesPlayed: true,
            profilePic: true,
          },
        },
      },
    });

    const userMap = new Map<string, {
      id: string;
      name: string;
      points: number;
      level: string;
      matchesPlayed: number;
      profilePic: string | null;
      venueBookingsCount: number;
    }>();

    for (const b of bookings) {
      if (!b.user) continue;
      const existing = userMap.get(b.userId);
      if (existing) {
        existing.venueBookingsCount += 1;
      } else {
        userMap.set(b.userId, {
          id: b.user.id,
          name: b.user.name,
          points: b.user.points,
          level: b.user.level,
          matchesPlayed: b.user.matchesPlayed,
          profilePic: b.user.profilePic,
          venueBookingsCount: 1,
        });
      }
    }

    const leaderboard = Array.from(userMap.values())
      .sort((a, b) => b.points - a.points || b.venueBookingsCount - a.venueBookingsCount)
      .slice(0, 20);

    res.status(200).json(leaderboard);
  } catch (error) {
    console.error('Error fetching venue leaderboard:', error);
    res.status(500).json({ error: 'Failed to fetch venue leaderboard' });
  }
});

// --- Court Routes ---
app.post('/api/venues/:id/courts', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const venueId = req.params.id as string;
    const venue = await prisma.venue.findUnique({ where: { id: venueId } });
    if (!venue) {
      res.status(404).json({ error: 'Venue not found' });
      return;
    }

    // Permit venue owner OR Super Admin
    if (venue.ownerId !== req.user!.userId && req.user!.role !== 'ADMIN') {
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
    console.error('Create court failed:', error);
    res.status(400).json({ error: 'Invalid data' });
  }
});

app.patch('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id as string;
    const court = await prisma.court.findUnique({ where: { id: courtId }, include: { venue: true } });
    if (!court) {
      res.status(404).json({ error: 'Court not found' });
      return;
    }

    // Permit venue owner OR Super Admin
    if (court.venue.ownerId !== req.user!.userId && req.user!.role !== 'ADMIN') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    const payload = { ...req.body };
    if (Array.isArray(payload.images)) payload.images = JSON.stringify(payload.images);
    if (Array.isArray(payload.amenities) || typeof payload.amenities === 'object') {
      payload.amenities = JSON.stringify(payload.amenities);
    }
    const updatedCourt = await prisma.court.update({ where: { id: courtId }, data: payload });
    res.json(updatedCourt);
  } catch (error) {
    console.error('Update court failed:', error);
    res.status(400).json({ error: 'Invalid data' });
  }
});

app.delete('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id as string;
    const court = await prisma.court.findUnique({ where: { id: courtId }, include: { venue: true } });
    if (!court) {
      res.status(404).json({ error: 'Court not found' });
      return;
    }

    // Permit venue owner OR Super Admin
    if (court.venue.ownerId !== req.user!.userId && req.user!.role !== 'ADMIN') {
      res.status(403).json({ error: 'Forbidden' });
      return;
    }

    await prisma.$transaction([
      prisma.booking.deleteMany({ where: { courtId } }),
      prisma.court.delete({ where: { id: courtId } })
    ]);

    res.json({ success: true, message: 'Court deleted successfully' });
  } catch (error) {
    console.error('Delete court failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/courts/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const courtId = req.params.id as string;
    const court = await prisma.court.findUnique({
      where: { id: courtId },
      include: { venue: true, bookings: true }
    });
    if (!court) {
      res.status(404).json({ error: 'Court not found' });
      return;
    }
    const formattedCourt = {
      ...court,
      images: typeof court.images === 'string'
        ? (court.images.startsWith('[') || court.images.startsWith('{') ? JSON.parse(court.images) : [court.images])
        : court.images,
      amenities: typeof court.amenities === 'string'
        ? (court.amenities.startsWith('[') || court.amenities.startsWith('{') ? JSON.parse(court.amenities) : court.amenities)
        : court.amenities,
    };
    res.json(formattedCourt);
  } catch (error) {
    console.error('Get court failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// --- Booking Routes (With Concurrency Control & Row Locking) ---
app.post('/api/bookings', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const { courtId, startTime, endTime, isManual } = req.body;
    const userId = req.user!.userId;

    if (!courtId || !startTime || !endTime) {
      res.status(400).json({ error: 'بيانات الحجز غير مكتملة (courtId, startTime, endTime مطلوبة)' });
      return;
    }

    const sTime = new Date(startTime);
    const eTime = new Date(endTime);

    if (isNaN(sTime.getTime()) || isNaN(eTime.getTime())) {
      res.status(400).json({ error: 'صيغة تاريخ الحجز غير صحيحة' });
      return;
    }

    if (sTime.getTime() >= eTime.getTime()) {
      res.status(400).json({ error: 'وقت بداية الحجز يجب أن يكون قبل وقت النهاية' });
      return;
    }

    const now = new Date();
    if (!isManual && sTime.getTime() < now.getTime() - 5 * 60 * 1000) {
      res.status(400).json({ error: 'لا يمكن حجز موعد في الماضي' });
      return;
    }

    // Atomic interactive transaction with pessimistic row lock on the Court record
    const booking = await prisma.$transaction(async (tx) => {
      // Row lock to serialize concurrent booking attempts for this specific court
      try {
        await tx.$executeRaw`SELECT id FROM "Court" WHERE id = ${courtId} FOR UPDATE`;
      } catch (lockErr) {
        // Graceful fallback if non-PostgreSQL engine
      }

      const court = await tx.court.findUnique({
        where: { id: courtId },
        include: { venue: { include: { owner: true } } }
      });

      if (!court) {
        throw new Error('COURT_NOT_FOUND');
      }

      // Check overlapping active bookings within the critical section
      const overlap = await tx.booking.findFirst({
        where: {
          courtId,
          status: { in: ['CONFIRMED', 'PENDING', 'ATTENDANCE_CONFIRMED'] },
          startTime: { lt: eTime },
          endTime: { gt: sTime }
        }
      });

      if (overlap) {
        throw new Error('BOOKING_OVERLAP');
      }

      const durationHours = (eTime.getTime() - sTime.getTime()) / 3600000;
      const price = Math.round(court.pricePerHour * durationHours * 100) / 100;
      const platformFee = Math.round(price * 0.05 * 100) / 100;
      const ownerAmount = Math.round((price - platformFee) * 100) / 100;

      return await tx.booking.create({
        data: {
          userId,
          courtId,
          startTime: sTime,
          endTime: eTime,
          price,
          platformFee,
          ownerAmount,
          status: 'CONFIRMED',
          paymentStatus: 'UNPAID',
          isManual: Boolean(isManual)
        },
        include: {
          court: { include: { venue: { include: { owner: true } } } }
        }
      });
    }, {
      maxWait: 5000,
      timeout: 10000,
    });

    // Asynchronous post-transaction actions
    awardGamificationPoints(userId, 50).catch((err) =>
      console.error('[Gamification] Error awarding points:', err)
    );

    if (booking.court.venue.owner.fcmToken) {
      sendPushNotification(
        booking.court.venue.owner.fcmToken,
        'حجز جديد! ⚽',
        `تم حجز ${booking.court.name} بتاريخ ${sTime.toLocaleDateString()}`
      ).catch((err) => console.error('[FCM] Push error:', err));
    }

    res.status(201).json(booking);
  } catch (error: any) {
    if (error?.message === 'COURT_NOT_FOUND') {
      res.status(404).json({ error: 'الملعب المطلوب غير موجود' });
      return;
    }
    if (error?.message === 'BOOKING_OVERLAP') {
      res.status(400).json({ error: 'هذا الموعد محجوز مسبقاً' });
      return;
    }
    console.error('Failed to create booking:', error);
    res.status(500).json({ error: 'Failed to create booking' });
  }
});

app.get('/api/bookings', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user!.userId;
    const bookings = await prisma.booking.findMany({
      where: {
        OR: [
          { userId: userId },
          { court: { venue: { ownerId: userId } } }
        ]
      },
      include: {
        court: { include: { venue: true } },
        user: { select: { id: true, name: true, phone: true } }
      },
      orderBy: { startTime: 'desc' }
    });
    res.json(bookings);
  } catch (error) {
    console.error('Get bookings failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// --- Booking Status Modification (With Ownership Guard) ---
app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id as string;
    const { status } = req.body;
    const callerId = req.user!.userId;
    const callerRole = req.user!.role;

    if (!status) {
      res.status(400).json({ error: 'Status is required' });
      return;
    }

    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        court: { include: { venue: { include: { owner: true } } } },
        user: true
      }
    });

    if (!booking) {
      res.status(404).json({ error: 'Booking not found' });
      return;
    }

    const isCreator = booking.userId === callerId;
    const isVenueOwner = booking.court.venue.ownerId === callerId;
    const isAdmin = callerRole === 'ADMIN';

    // Authorization verification
    if (!isCreator && !isVenueOwner && !isAdmin) {
      res.status(403).json({ error: 'غير مصرح لك بتعديل حالة هذا الحجز' });
      return;
    }

    // Role-based state transition validation
    if (isCreator && !isVenueOwner && !isAdmin) {
      if (status !== 'CANCELLED') {
        res.status(403).json({ error: 'يحق للاعب إلغاء الحجز الخاص به فقط' });
        return;
      }
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
        sendPushNotification(
          booking.user.fcmToken,
          'تم رفض حجزك ❌',
          `قام المالك بإلغاء حجزك في ${booking.court.name}.`
        ).catch(() => {});
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
        sendPushNotification(
          booking.court.venue.owner.fcmToken,
          'إلغاء حجز من اللاعب ❌',
          `قام اللاعب ${booking.user.name} بإلغاء حجزه في ${booking.court.name}.`
        ).catch(() => {});
      }
    }

    res.json(updated);
  } catch (error) {
    console.error('Update booking status failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// --- Attendance Confirmation (With Creator/Admin Guard) ---
app.post('/api/bookings/:id/confirm-attendance', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id as string;
    const callerId = req.user!.userId;
    const callerRole = req.user!.role;

    const booking = await prisma.booking.findUnique({
      where: { id: bookingId },
      include: {
        court: { include: { venue: { include: { owner: true } } } },
        user: true
      }
    });

    if (!booking) {
      res.status(404).json({ error: 'Booking not found' });
      return;
    }

    // Verification Guard: Only booking creator or Super Admin can confirm attendance
    if (booking.userId !== callerId && callerRole !== 'ADMIN') {
      res.status(403).json({ error: 'تأكيد الحضور متاح فقط لصاحب الحجز الأصلي' });
      return;
    }

    if (booking.status === 'CANCELLED' || booking.status === 'REJECTED') {
      res.status(400).json({ error: 'لا يمكن تأكيد الحضور لحجز تم إلغاؤه أو رفضه' });
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
      sendPushNotification(
        booking.court.venue.owner.fcmToken,
        'تأكيد حضور اللاعب ✅',
        `قام اللاعب ${booking.user.name} بتأكيد حضوره لحجز ${booking.court.name}`
      ).catch(() => {});
    }

    res.json(updated);
  } catch (error) {
    console.error('Confirm attendance failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// --- Match Requests & Community Game Chat ---
app.get('/api/match-requests', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const matches = await prisma.matchRequest.findMany({
      where: { matchTime: { gt: new Date() }, status: 'OPEN' },
      include: { creator: { select: { id: true, name: true, profilePic: true, level: true } } },
      orderBy: { matchTime: 'asc' }
    });
    res.json(matches);
  } catch (error) {
    console.error('Get match requests failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

app.post('/api/match-requests', requireAuth, async (req: Request, res: Response): Promise<void> => {
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
    res.status(201).json(match);
  } catch (error) {
    console.error('Create match request failed:', error);
    res.status(500).json({ error: 'Failed' });
  }
});

// GET /api/matches/:id/messages
app.get('/api/matches/:id/messages', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const matchId = req.params.id as string;
    if (!matchId) {
      res.status(400).json({ error: 'Match ID is required' });
      return;
    }

    const match = await prisma.matchRequest.findUnique({
      where: { id: matchId },
      select: { id: true }
    });

    if (!match) {
      res.status(404).json({ error: 'Match request not found' });
      return;
    }

    const messages = await prisma.message.findMany({
      where: { matchRequestId: matchId },
      orderBy: { createdAt: 'asc' },
      include: {
        sender: {
          select: {
            id: true,
            name: true,
            profilePic: true,
            level: true
          }
        }
      }
    });

    // Provide both profilePic and avatarUrl for full Flutter compatibility
    const formatted = messages.map((msg) => ({
      id: msg.id,
      content: msg.content,
      matchRequestId: msg.matchRequestId,
      senderId: msg.senderId,
      createdAt: msg.createdAt,
      sender: {
        id: msg.sender.id,
        name: msg.sender.name,
        profilePic: msg.sender.profilePic,
        avatarUrl: msg.sender.profilePic,
        level: msg.sender.level,
      }
    }));

    res.status(200).json(formatted);
  } catch (error) {
    console.error('Error fetching match messages:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

// POST /api/matches/:id/messages
app.post('/api/matches/:id/messages', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const matchId = req.params.id as string;
    const { content } = req.body;

    if (!matchId) {
      res.status(400).json({ error: 'Match ID is required' });
      return;
    }

    if (!content || typeof content !== 'string' || content.trim().length === 0) {
      res.status(400).json({ error: 'Message content cannot be empty' });
      return;
    }

    const match = await prisma.matchRequest.findUnique({
      where: { id: matchId },
      select: { id: true, status: true }
    });

    if (!match) {
      res.status(404).json({ error: 'Match request not found' });
      return;
    }

    const message = await prisma.message.create({
      data: {
        content: content.trim(),
        matchRequestId: matchId,
        senderId: req.user!.userId,
      },
      include: {
        sender: {
          select: {
            id: true,
            name: true,
            profilePic: true,
            level: true
          }
        }
      }
    });

    const responsePayload = {
      id: message.id,
      content: message.content,
      matchRequestId: message.matchRequestId,
      senderId: message.senderId,
      createdAt: message.createdAt,
      sender: {
        id: message.sender.id,
        name: message.sender.name,
        profilePic: message.sender.profilePic,
        avatarUrl: message.sender.profilePic,
        level: message.sender.level
      }
    };

    res.status(201).json(responsePayload);
  } catch (error) {
    console.error('Error posting match message:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

// --- Notifications Routes ---
app.get('/api/notifications', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const notifs = await prisma.notification.findMany({
      where: { userId: req.user!.userId },
      orderBy: { createdAt: 'desc' }
    });
    res.json(notifs);
  } catch (error) {
    console.error('Get notifications failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// PATCH /api/notifications/read-all
app.patch('/api/notifications/read-all', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user!.userId;
    const result = await prisma.notification.updateMany({
      where: {
        userId,
        isRead: false
      },
      data: {
        isRead: true
      }
    });

    res.status(200).json({
      success: true,
      count: result.count,
      message: 'All notifications marked as read'
    });
  } catch (error) {
    console.error('Error marking notifications as read:', error);
    res.status(500).json({ error: 'Failed to mark notifications as read' });
  }
});

// --- Admin Routes ---
app.get('/api/admin/stats', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const totalUsers = await prisma.user.count();
    const totalVenues = await prisma.venue.count();
    const totalBookings = await prisma.booking.count();
    const bookings = await prisma.booking.findMany({
      where: { status: { in: ['CONFIRMED', 'ATTENDANCE_CONFIRMED', 'ATTENDED', 'COMPLETED'] } }
    });
    
    // 5% commission calculation
    const totalRevenue = bookings.reduce((sum, b) => sum + (b.price || 0), 0) * 0.05;
    res.json({ totalUsers, totalVenues, totalBookings, totalRevenue });
  } catch (error) {
    console.error('Admin stats failed:', error);
    res.status(500).json({ error: 'Server error' });
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
    res.json(sanitizeUsers(users));
  } catch (error) {
    console.error('Admin users failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

app.get('/api/admin/venues', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const venues = await prisma.venue.findMany({
      include: {
        owner: { select: { id: true, name: true, phone: true, role: true, profilePic: true } },
        courts: true
      },
      orderBy: { createdAt: 'desc' }
    });
    res.json(venues);
  } catch (error) {
    console.error('Admin venues failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// GET /api/admin/bookings (Called by Web Dashboard)
app.get('/api/admin/bookings', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const bookings = await prisma.booking.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, name: true, phone: true } },
        court: { include: { venue: { select: { id: true, name: true } } } }
      }
    });
    res.status(200).json(bookings);
  } catch (error) {
    console.error('Admin bookings failed:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/admin/users/:id/toggle-ban
app.post('/api/admin/users/:id/toggle-ban', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const targetUserId = req.params.id as string;

    if (!targetUserId) {
      res.status(400).json({ error: 'User ID is required' });
      return;
    }

    if (targetUserId === req.user!.userId) {
      res.status(400).json({ error: 'Cannot ban your own account' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, isActive: true, role: true }
    });

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const updated = await prisma.user.update({
      where: { id: targetUserId },
      data: { isActive: !user.isActive },
      select: {
        id: true,
        name: true,
        phone: true,
        role: true,
        isActive: true,
        points: true,
        level: true,
        createdAt: true
      }
    });

    res.status(200).json({
      success: true,
      isActive: updated.isActive,
      isBanned: !updated.isActive,
      user: updated
    });
  } catch (error) {
    console.error('Error toggling user ban status:', error);
    res.status(500).json({ error: 'Failed to update user status' });
  }
});

// DELETE /api/admin/users/:id
app.delete('/api/admin/users/:id', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const targetUserId = req.params.id as string;
    if (targetUserId === req.user!.userId) {
      res.status(400).json({ error: 'Cannot delete your own account' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      include: { venues: { select: { id: true, courts: { select: { id: true } } } } }
    });
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    const userVenueIds = user.venues.map((v) => v.id);
    const userVenueCourtIds = user.venues.flatMap((v) => v.courts.map((c) => c.id));

    await prisma.$transaction([
      prisma.notification.deleteMany({ where: { userId: targetUserId } }),
      prisma.message.deleteMany({ where: { senderId: targetUserId } }),
      prisma.review.deleteMany({ where: { userId: targetUserId } }),
      prisma.booking.deleteMany({ where: { userId: targetUserId } }),
      prisma.matchRequest.deleteMany({ where: { creatorId: targetUserId } }),
      ...(userVenueCourtIds.length > 0 ? [prisma.booking.deleteMany({ where: { courtId: { in: userVenueCourtIds } } })] : []),
      ...(userVenueIds.length > 0 ? [prisma.review.deleteMany({ where: { venueId: { in: userVenueIds } } })] : []),
      ...(userVenueIds.length > 0 ? [prisma.court.deleteMany({ where: { venueId: { in: userVenueIds } } })] : []),
      ...(userVenueIds.length > 0 ? [prisma.venue.deleteMany({ where: { id: { in: userVenueIds } } })] : []),
      prisma.user.delete({ where: { id: targetUserId } })
    ]);

    res.status(200).json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// Reusable Cascade Venue Deletion Handler
const deleteVenueCascadeHandler = async (req: Request, res: Response): Promise<void> => {
  try {
    const venueId = req.params.id as string;
    if (!venueId) {
      res.status(400).json({ error: 'Venue ID is required' });
      return;
    }

    const venue = await prisma.venue.findUnique({
      where: { id: venueId },
      include: { courts: { select: { id: true } } }
    });

    if (!venue) {
      res.status(404).json({ error: 'Venue not found' });
      return;
    }

    const courtIds = venue.courts.map((c) => c.id);

    await prisma.$transaction([
      ...(courtIds.length > 0 ? [prisma.booking.deleteMany({ where: { courtId: { in: courtIds } } })] : []),
      prisma.review.deleteMany({ where: { venueId } }),
      ...(courtIds.length > 0 ? [prisma.court.deleteMany({ where: { venueId } })] : []),
      prisma.venue.delete({ where: { id: venueId } })
    ]);

    res.status(200).json({
      success: true,
      message: 'Venue and all associated courts, reviews, and bookings deleted successfully'
    });
  } catch (error: any) {
    console.error('Error cascade deleting venue:', error);
    res.status(500).json({ error: 'Failed to delete venue' });
  }
};

app.delete('/api/admin/venues/:id', requireAuth, requireRole(['ADMIN']), deleteVenueCascadeHandler);
app.delete('/api/admin/pitches/:id', requireAuth, requireRole(['ADMIN']), deleteVenueCascadeHandler);

// --- AI Assistant Endpoint ---
app.post('/api/ai-assistant', async (req: Request, res: Response): Promise<void> => {
  res.status(200).json({
    reply: 'أهلاً بك في سبوتايا! يمكنك تصفح الملاعب والنوادي الرياضية المتاحة وحجز موعدك بسهولة من التطبيق.'
  });
});

// --- Attendance Reminder Cron Job (With Deduplication) ---
cron.schedule('*/30 * * * *', async () => {
  try {
    console.log('[Cron] Running attendance reminder cron job...');
    const now = new Date();
    const twoHoursFromNow = new Date(now.getTime() + 2 * 60 * 60 * 1000);
    
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
      // Deduplicate: avoid sending if reminder notification was already created in last 2 hours
      const recentReminder = await prisma.notification.findFirst({
        where: {
          userId: b.userId,
          type: 'ATTENDANCE_REMINDER',
          createdAt: { gte: new Date(now.getTime() - 2 * 60 * 60 * 1000) }
        }
      });

      if (recentReminder) {
        continue;
      }

      await prisma.notification.create({
        data: {
          userId: b.userId,
          title: 'تأكيد الحضور ضروري ⚠️',
          body: `متبقي أقل من ساعتين على حجزك في ${b.court.name}! برجاء الدخول وتأكيد الحضور الآن لضمان الحجز وعدم إلغائه.`,
          type: 'ATTENDANCE_REMINDER'
        }
      });
      
      if (b.user.fcmToken) {
        sendPushNotification(
          b.user.fcmToken,
          'تأكيد الحضور ضروري ⚠️',
          `متبقي أقل من ساعتين على حجزك في ${b.court.name}! برجاء الدخول وتأكيد الحضور الآن.`
        ).catch(() => {});
      }
    }
  } catch (e) {
    console.error('[Cron] Job error:', e);
  }
});

// --- Global Express JSON Error Handler ---
app.use((err: any, req: Request, res: Response, next: NextFunction): void => {
  if (res.headersSent) {
    return next(err);
  }

  console.error(`[API Error] ${req.method} ${req.originalUrl}:`, err);

  // 1. JSON Syntax Error from body-parser
  if (err instanceof SyntaxError && 'status' in err && (err as any).status === 400 && 'body' in err) {
    res.status(400).json({ error: 'صيغة البيانات غير صحيحة (Malformed JSON)' });
    return;
  }

  // 2. Multer Errors
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      res.status(400).json({ error: 'حجم الملف يتجاوز الحد الأقصى المسموح به (5MB)' });
      return;
    }
    if (err.code === 'LIMIT_FILE_COUNT' || err.code === 'LIMIT_UNEXPECTED_FILE') {
      res.status(400).json({ error: 'عدد الملفات يتجاوز الحد الأقصى المسموح به (5 صور)' });
      return;
    }
    res.status(400).json({ error: `خطأ في رفع الملف: ${err.message}` });
    return;
  }

  // 3. Prisma Known Request Errors
  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2002') {
      const target = (err.meta?.target as string[])?.join(', ') || 'الحقل';
      res.status(400).json({ error: `هذا ${target} مسجل بالفعل مسبقاً` });
      return;
    }
    if (err.code === 'P2025') {
      res.status(404).json({ error: 'العنصر المطلوب غير موجود' });
      return;
    }
    if (err.code === 'P2003') {
      res.status(400).json({ error: 'البيانات المرتبطة غير صحيحة' });
      return;
    }
  }

  // 4. JWT Authentication Errors
  if (err.name === 'JsonWebTokenError') {
    res.status(401).json({ error: 'رمز الدخول غير صالح (Invalid token)' });
    return;
  }
  if (err.name === 'TokenExpiredError') {
    res.status(401).json({ error: 'انتهت صلاحية الجلسة، برجاء تسجيل الدخول مجدداً' });
    return;
  }

  // 5. Generic Fallback (always JSON, never HTML)
  const status = typeof err.statusCode === 'number' ? err.statusCode :
                 typeof err.status === 'number' ? err.status : 500;

  const message = status < 500 && err.message 
    ? err.message 
    : 'حدث خطأ في الخادم، يرجى المحاولة لاحقاً';

  res.status(status).json({ error: message });
});

// --- 404 Fallback Handler ---
app.use((req: Request, res: Response): void => {
  res.status(404).json({ error: `المسار غير موجود: ${req.method} ${req.originalUrl}` });
});

// --- Server Startup ---
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});

export default app;
