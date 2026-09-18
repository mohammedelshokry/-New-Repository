// @ts-nocheck
import express, { Request, Response, NextFunction } from 'express';
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
    const { profilePic, name, phone } = req.body;
    
    // Only update fields that are provided
    const dataToUpdate: any = {};
    if (profilePic !== undefined) dataToUpdate.profilePic = profilePic;
    if (name !== undefined) dataToUpdate.name = name;
    if (phone !== undefined) dataToUpdate.phone = phone;

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
    
    res.status(201).json(booking);
  } catch (e: any) {
    res.status(400).json({ error: e.message });
  }
});

app.get('/api/bookings', requireAuth, async (req: Request, res: Response) => {
  const bookings = await prisma.booking.findMany({
    where: req.user!.role === 'OWNER' ? { pitch: { ownerId: req.user!.userId } } : { userId: req.user!.userId },
    include: { pitch: true, user: { select: { name: true, phone: true } } }
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

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

export default app;

