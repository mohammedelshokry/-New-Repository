import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const app = express();
const prisma = new PrismaClient();
const port = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Health check
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// Helper: safely parse JSON strings stored in SQLite
function safeParse(str: string): any[] {
  try { return JSON.parse(str); } catch { return []; }
}

// ─── Pitches ───────────────────────────────────────────────

// Get all pitches
app.get('/api/pitches', async (_req, res) => {
  try {
    const pitches = await prisma.pitch.findMany();
    const formatted = pitches.map((p) => ({
      ...p,
      amenities: safeParse(p.amenities),
      images: safeParse(p.images),
    }));
    res.json(formatted);
  } catch (error) {
    console.error('GET /api/pitches error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get pitch by ID with bookings for the next 7 days
app.get('/api/pitches/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const pitch = await prisma.pitch.findUnique({ where: { id } });

    if (!pitch) {
      return res.status(404).json({ error: 'Pitch not found' });
    }

    const now = new Date();
    const nextWeek = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    const bookings = await prisma.booking.findMany({
      where: {
        pitchId: id,
        startTime: { gte: now, lte: nextWeek },
      },
    });

    res.json({
      ...pitch,
      amenities: safeParse(pitch.amenities),
      images: safeParse(pitch.images),
      bookings,
    });
  } catch (error) {
    console.error('GET /api/pitches/:id error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── Bookings ──────────────────────────────────────────────

// Create a booking
app.post('/api/bookings', async (req, res) => {
  try {
    const { userId, pitchId, startTime, endTime } = req.body;

    if (!userId || !pitchId || !startTime || !endTime) {
      return res.status(400).json({ error: 'Missing required fields (userId, pitchId, startTime, endTime)' });
    }

    // Validate pitch exists
    const pitch = await prisma.pitch.findUnique({ where: { id: pitchId } });
    if (!pitch) {
      return res.status(404).json({ error: 'Pitch not found' });
    }

    // Validate user exists
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Check for overlapping bookings
    const overlapping = await prisma.booking.findFirst({
      where: {
        pitchId,
        status: { not: 'CANCELLED' },
        AND: [
          { startTime: { lt: new Date(endTime) } },
          { endTime: { gt: new Date(startTime) } },
        ],
      },
    });

    if (overlapping) {
      return res.status(409).json({ error: 'Slot already booked' });
    }

    const booking = await prisma.booking.create({
      data: {
        userId,
        pitchId,
        startTime: new Date(startTime),
        endTime: new Date(endTime),
        status: 'CONFIRMED',
      },
    });

    res.status(201).json(booking);
  } catch (error) {
    console.error('POST /api/bookings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get bookings for a user
app.get('/api/bookings/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const bookings = await prisma.booking.findMany({
      where: { userId },
      include: { pitch: true },
      orderBy: { startTime: 'desc' },
    });

    const formatted = bookings.map((b) => ({
      ...b,
      pitch: {
        ...b.pitch,
        amenities: safeParse(b.pitch.amenities),
        images: safeParse(b.pitch.images),
      },
    }));

    res.json(formatted);
  } catch (error) {
    console.error('GET /api/bookings/:userId error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Cancel a booking
app.patch('/api/bookings/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;
    const booking = await prisma.booking.findUnique({ where: { id } });

    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }
    if (booking.status === 'CANCELLED') {
      return res.status(400).json({ error: 'Booking already cancelled' });
    }

    const updated = await prisma.booking.update({
      where: { id },
      data: { status: 'CANCELLED' },
    });

    res.json(updated);
  } catch (error) {
    console.error('PATCH /api/bookings/:id/cancel error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── Match Requests (Find a Teammate) ─────────────────────

// Get all open match requests
app.get('/api/match-requests', async (_req, res) => {
  try {
    const requests = await prisma.matchRequest.findMany({
      where: { status: 'OPEN' },
      include: {
        creator: { select: { id: true, name: true, phone: true } },
      },
      orderBy: { matchTime: 'asc' },
    });
    res.json(requests);
  } catch (error) {
    console.error('GET /api/match-requests error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create a match request
app.post('/api/match-requests', async (req, res) => {
  try {
    const { creatorId, title, description, matchTime, missingSpots, costPerSpot } = req.body;

    if (!creatorId || !title || !matchTime || !missingSpots || !costPerSpot) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const creator = await prisma.user.findUnique({ where: { id: creatorId } });
    if (!creator) {
      return res.status(404).json({ error: 'Creator not found' });
    }

    const matchRequest = await prisma.matchRequest.create({
      data: {
        creatorId,
        title,
        description: description || '',
        matchTime: new Date(matchTime),
        missingSpots,
        costPerSpot,
      },
    });

    res.status(201).json(matchRequest);
  } catch (error) {
    console.error('POST /api/match-requests error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create a new pitch (for Pitch Owners)
app.post('/api/pitches', async (req, res) => {
  try {
    const { name, description, location, surface, indoor, amenities, pricePerHour, images } = req.body;

    if (!name || !location || !pricePerHour) {
      return res.status(400).json({ error: 'Name, location, and pricePerHour are required' });
    }

    const pitch = await prisma.pitch.create({
      data: {
        name,
        description: description || '',
        location,
        surface: surface || 'Artificial Grass',
        indoor: Boolean(indoor),
        amenities: JSON.stringify(amenities || ['Parking', 'Changing Rooms']),
        pricePerHour: Number(pricePerHour),
        images: JSON.stringify(images || ['https://images.unsplash.com/photo-1579952363873-27f3bade9f55?q=80&w=800&auto=format&fit=crop']),
      },
    });

    res.status(201).json({
      ...pitch,
      amenities: safeParse(pitch.amenities),
      images: safeParse(pitch.images),
    });
  } catch (error) {
    console.error('POST /api/pitches error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── Users & Auth ──────────────────────────────────────────

// User Registration
app.post('/api/users/register', async (req, res) => {
  try {
    const { name, phone, role } = req.body;

    if (!name || !phone) {
      return res.status(400).json({ error: 'Name and phone are required' });
    }

    const existing = await prisma.user.findUnique({ where: { phone } });
    if (existing) {
      return res.status(400).json({ error: 'رقم الهاتف مسجل بالفعل، يمكنك تسجيل الدخول' });
    }

    const user = await prisma.user.create({
      data: {
        name,
        phone,
        role: role === 'OWNER' ? 'OWNER' : 'PLAYER',
      },
    });

    res.status(201).json(user);
  } catch (error) {
    console.error('POST /api/users/register error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// User Login
app.post('/api/users/login', async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ error: 'رقم الهاتف مطلوب' });
    }

    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user) {
      return res.status(404).json({ error: 'رقم الهاتف غير مسجل' });
    }

    res.json(user);
  } catch (error) {
    console.error('POST /api/users/login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all users (for admin)
app.get('/api/users', async (_req, res) => {
  try {
    const users = await prisma.user.findMany({
      select: { id: true, name: true, phone: true, role: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json(users);
  } catch (error) {
    console.error('GET /api/users error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ─── Super Admin Master Control Endpoints ──────────────────

// Admin Dashboard Summary Stats
app.get('/api/admin/stats', async (_req, res) => {
  try {
    const [totalUsers, totalPlayers, totalOwners, totalPitches, totalBookings] = await Promise.all([
      prisma.user.count(),
      prisma.user.count({ where: { role: 'PLAYER' } }),
      prisma.user.count({ where: { role: 'OWNER' } }),
      prisma.pitch.count(),
      prisma.booking.count(),
    ]);

    // Calculate approximate platform volume and 10% commission
    const bookings = await prisma.booking.findMany({
      include: { pitch: { select: { pricePerHour: true } } },
    });

    const totalRevenue = bookings.reduce((sum, b) => sum + (b.pitch?.pricePerHour || 0), 0);
    const platformCommission = Math.round(totalRevenue * 0.10); // 10% commission

    res.json({
      totalUsers,
      totalPlayers,
      totalOwners,
      totalPitches,
      totalBookings,
      totalRevenue,
      platformCommission,
    });
  } catch (error) {
    console.error('GET /api/admin/stats error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Admin All Bookings with full details
app.get('/api/admin/bookings', async (_req, res) => {
  try {
    const bookings = await prisma.booking.findMany({
      include: {
        user: { select: { name: true, phone: true } },
        pitch: { select: { name: true, location: true, pricePerHour: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    res.json(bookings);
  } catch (error) {
    console.error('GET /api/admin/bookings error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Admin Delete Pitch
app.delete('/api/admin/pitches/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await prisma.booking.deleteMany({ where: { pitchId: id } });
    await prisma.pitch.delete({ where: { id } });
    res.json({ success: true, message: 'تم حذف الملعب بنجاح' });
  } catch (error) {
    console.error('DELETE /api/admin/pitches/:id error:', error);
    res.status(500).json({ error: 'Failed to delete pitch' });
  }
});

// Admin Delete User
app.delete('/api/admin/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await prisma.booking.deleteMany({ where: { userId: id } });
    await prisma.matchRequest.deleteMany({ where: { creatorId: id } });
    await prisma.user.delete({ where: { id } });
    res.json({ success: true, message: 'تم حذف المستخدم بنجاح' });
  } catch (error) {
    console.error('DELETE /api/admin/users/:id error:', error);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// ─── Start Server ──────────────────────────────────────────

app.listen(port, () => {
  console.log(`PitchUp API running at http://localhost:${port}`);
});
