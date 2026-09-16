// @ts-nocheck
import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { z } from 'zod';

const app = express();
const prisma = new PrismaClient();
const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev-only';

app.use(cors({ origin: '*' })); // Update to specific origin in production
app.use(express.json());
app.get('/api/debug', (req: Request, res: Response) => {
  res.json({
    env: process.env.NODE_ENV,
    hasDbUrl: !!process.env.DATABASE_URL,
    hasJwt: !!process.env.JWT_SECRET,
    dir: __dirname,
    cwd: process.cwd(),
    prismaClient: typeof PrismaClient
  });
});

declare global {
  namespace Express {
    interface Request {
      user?: { id: string; role: string; phone: string };
    }
  }
}

const requireRole = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user || !roles.includes(req.user.role)) {
      res.status(403).json({ error: 'Ã™â€¦Ã™â€¦Ã™â€ Ã™Ë†Ã˜Â¹ Ã˜Â§Ã™â€žÃ˜Â¯Ã˜Â®Ã™Ë†Ã™â€ž' });
      return;
    }
    next();
  };
};
const authMiddleware = (req: Request, res: Response, next: NextFunction): void => {
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

const requireRold = (roles: string[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user || !roles.includes(req.user.role)) {
      res.status(403).json({ error: 'Forbidden: Insufficient permissions' });
      return;
    }
    next();
  };
};

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.post('/api/auth/register', async (req: Request, res: Response) => {
  try {
    const schema = z.object({
      name: z.string().min(2),
      phone: z.string().min(10),
      password: z.string().min(6),
    });
    const { name, phone, password } = schema.parse(req.body);

    const existingUser = await prisma.user.findUnique({ where: { phone } });
    if (existingUser) {
      res.status(400).json({ error: 'Phone already registered' });
      return;
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: { name, phone, passwordHash, role: 'PLAYER' }
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
    if (!user || !user.isActive) {
      res.status(401).json({ error: 'Invalid credentials or inactive account' });
      return;
    }

    const isValid = await bcrypt.compare(password, user.passwordHash);
    if (!isValid) {
      res.status(401).json({ error: 'Invalid credentials' });
      return;
    }

    const token = jwt.sign({ id: user.id, role: user.role, phone: user.phone }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, user: { id: user.id, name: user.name, role: user.role } });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.get('/api/auth/me', authMiddleware, async (req: Request, res: Response) => {
  const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
  if (!user) {
    res.status(404).json({ error: 'User not found' });
    return;
  }
  res.json({ id: user.id, name: user.name, phone: user.phone, role: user.role, isActive: user.isActive });
});

// Admin endpoints
app.post('/api/admin/users', authMiddleware, requireRole(['ADMIN']), async (req: Request, res: Response) => {
  try {
    const { name, phone, password, role } = req.body;
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: { name, phone, passwordHash, role }
    });
    res.status(201).json(user);
  } catch (error) {
    res.status(400).json({ error: 'Invalid data' });
  }
});

app.get('/api/admin/users', authMiddleware, requireRole(['ADMIN']), async (req: Request, res: Response) => {
  const users = await prisma.user.findMany({ select: { id: true, name: true, phone: true, role: true, isActive: true } });
  res.json(users);
});

app.patch('/api/admin/users/:id/status', authMiddleware, requireRole(['ADMIN']), async (req: Request, res: Response) => {
  const { isActive } = req.body;
  const user = await prisma.user.update({
    where: { id: req.params.id },
    data: { isActive }
  });
  res.json(user);
});

// Pitches
app.get('/api/pitches', async (req: Request, res: Response) => {
  const pitches = await prisma.pitch.findMany({ where: { isActive: true }, include: { owner: { select: { name: true } } } });
  res.json(pitches);
});

app.post('/api/pitches', authMiddleware, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response) => {
  try {
    const { name, description, location, surface, indoor, amenities, pricePerHour, images } = req.body;
    const pitch = await prisma.pitch.create({
      data: {
        name, description, location, surface, indoor,
        amenities: JSON.stringify(amenities),
        pricePerHour,
        images: JSON.stringify(images),
        ownerId: req.user!.id
      }
    });
    res.status(201).json(pitch);
  } catch (error) {
    res.status(400).json({ error: 'Invalid data' });
  }
});

app.patch('/api/pitches/:id/status', authMiddleware, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response) => {
  const { isActive } = req.body;
  const pitch = await prisma.pitch.findUnique({ where: { id: req.params.id } });
  if (!pitch) return;
  if (req.user!.role !== 'ADMIN' && pitch.ownerId !== req.user!.id) {
    res.status(403).json({ error: 'Forbidden' });
    return;
  }
  const updated = await prisma.pitch.update({ where: { id: req.params.id }, data: { isActive } });
  res.json(updated);
});

// Bookings

  app.get('/api/match-requests', authMiddleware, async (req: Request, res: Response) => {
    try {
      const matchRequests = await prisma.matchRequest.findMany({
        include: { creator: { select: { name: true, phone: true } } },
        orderBy: { createdAt: 'desc' }
      });
      res.json(matchRequests);
    } catch (e) {
      res.status(500).json({ error: 'Failed to fetch match requests' });
    }
  });

  app.post('/api/bookings', authMiddleware, async (req: Request, res: Response) => {
  try {
    const { pitchId, startTime, endTime } = req.body;
    const start = new Date(startTime);
    const end = new Date(endTime);

    if (start >= end) {
      res.status(400).json({ error: 'End time must be after start time' });
      return;
    }

    const pitch = await prisma.pitch.findUnique({ where: { id: pitchId } });
    if (!pitch || !pitch.isActive) {
      res.status(404).json({ error: 'Pitch not found or inactive' });
      return;
    }

    // Overlap check
    const overlapping = await prisma.booking.findFirst({
      where: {
        pitchId,
        status: 'CONFIRMED',
        startTime: { lt: end },
        endTime: { gt: start }
      }
    });

    if (overlapping) {
      res.status(409).json({ error: 'Timeslot is already booked' });
      return;
    }

    // Financial calculations
    const hours = (end.getTime() - start.getTime()) / (1000 * 60 * 60);
    const price = hours * pitch.pricePerHour;
    const platformFee = price * 0.10; // 10%
    const ownerAmount = price - platformFee;

    const booking = await prisma.booking.create({
      data: {
        userId: req.user!.id,
        pitchId,
        startTime: start,
        endTime: end,
        price,
        platformFee,
        ownerAmount
      }
    });

    res.status(201).json(booking);
  } catch (error) {
    res.status(400).json({ error: 'Invalid request' });
  }
});

app.get('/api/bookings', authMiddleware, async (req: Request, res: Response) => {
  const bookings = await prisma.booking.findMany({
    where: { userId: req.user!.id },
    include: { pitch: true }
  });
  res.json(bookings);
});

app.get('/api/owner/bookings', authMiddleware, requireRole(['OWNER']), async (req: Request, res: Response) => {
  const bookings = await prisma.booking.findMany({
    where: { pitch: { ownerId: req.user!.id } },
    include: { pitch: true, user: { select: { name: true, phone: true } } }
  });
  res.json(bookings);
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

export default app;
