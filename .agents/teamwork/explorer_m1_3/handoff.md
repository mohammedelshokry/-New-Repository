# Security, Concurrency & Infrastructure Architecture Report (Milestone 1 — Explorer 3)

## 1. Observation

### 1.1 Concurrency & Double-Booking Vulnerability in `POST /api/bookings`
**Target File**: `backend/src/index.ts:355-411`
```ts
355: app.post('/api/bookings', requireAuth, async (req: Request, res: Response): Promise<void> => {
356:   try {
357:     const { courtId, startTime, endTime, isManual } = req.body;
358:     const sTime = new Date(startTime);
359:     const eTime = new Date(endTime);
360: 
361:     const overlap = await prisma.booking.findFirst({
362:       where: { courtId, status: { in: ['CONFIRMED', 'PENDING', 'ATTENDANCE_CONFIRMED'] }, OR: [ { startTime: { lt: eTime }, endTime: { gt: sTime } } ] }
363:     });
364: 
365:     if (overlap) {
366:       res.status(400).json({ error: 'هذا الموعد محجوز مسبقاً' });
367:       return;
368:     }
369: 
370:     const court = await prisma.court.findUnique({ where: { id: courtId }, include: { venue: { include: { owner: true } } } });
...
380:     const booking = await prisma.booking.create({
381:       data: {
382:         userId: req.user!.userId,
383:         courtId,
384:         startTime: sTime,
385:         status: 'CONFIRMED',
386:         endTime: eTime,
387:         price,
388:         platformFee,
389:         ownerAmount,
390:         isManual: isManual || false
391:       }
392:     });
393: 
394:     // Award Points
395:     await awardGamificationPoints(req.user!.userId, 50);
396: 
397:     // Notify Owner
398:     if (court.venue.owner.fcmToken) {
399:       try {
400:         await admin.messaging().send({ 
401:           token: court.venue.owner.fcmToken, 
402:           notification: { title: 'حجز جديد! ⚽', body: `تم حجز غرفة/ملعب ${court.name} بتاريخ ${sTime.toLocaleDateString()}` } 
403:         });
404:       } catch (e) {}
405:     }
406: 
407:     res.status(201).json(booking);
408:   } catch (error) {
409:     console.error(error); res.status(500).json({ error: 'Failed to create booking' });
410:   }
411: });
```
- **Direct Observations**:
  1. The overlap check (`prisma.booking.findFirst`, line 361) and insertion (`prisma.booking.create`, line 380) run in separate, non-transactional database operations.
  2. In the PostgreSQL schema (`prisma/schema.prisma:73-95`), `Booking` has no unique constraint or exclusion constraint across `(courtId, startTime, endTime)`.
  3. Under concurrent execution, two simultaneous requests for the same court and overlapping time slots both find `overlap === null` and both execute `prisma.booking.create()`, resulting in confirmed double-bookings.
  4. External side effects (gamification DB writes at line 395 and Firebase push notifications at line 400) run synchronously before the HTTP response is sent, coupling external network latency to request completion.
  5. Missing timestamp sanity checks: no verification that `sTime < eTime`, that duration is positive, or that `sTime > Date.now()`.

---

### 1.2 Privilege Escalation & Authorization Flaws

#### A. Public Privilege Escalation to Super Admin (`src/index.ts:116-133`)
```ts
116: app.post('/api/auth/register', async (req: Request, res: Response): Promise<void> => {
117:   try {
118:     const { name, phone, password, role } = req.body;
...
125:     const user = await prisma.user.create({
126:       data: { name, phone, passwordHash, role: role || 'PLAYER' }
127:     });
128:     const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET);
129:     res.json({ user, token });
```
- **Direct Observation**: An unauthenticated public caller can supply `{ role: 'ADMIN' }` in the POST body to register a super administrator account with full platform permissions. Furthermore, line 129 returns `user` containing `passwordHash`.

#### B. Broken Authorization in Booking Status Modification (`src/index.ts:517-535`)
```ts
517: app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response): Promise<void> => {
518:   try {
519:     const bookingId = req.params.id;
520:     const { status } = req.body;
521:     
522:     const booking = await prisma.booking.findUnique({
523:       where: { id: bookingId },
524:       include: { court: { include: { venue: { include: { owner: true } } } }, user: true }
525:     });
...
532:     const updated = await prisma.booking.update({
533:       where: { id: bookingId },
534:       data: { status }
535:     });
```
- **Direct Observation**: Zero caller identity checks between line 525 and line 532. Any authenticated user can modify the status of ANY booking in the database (e.g. cancelling or rejecting bookings belonging to other players or other venue owners).

#### C. Broken Authorization in Attendance Confirmation (`src/index.ts:570-586`)
```ts
570: app.post('/api/bookings/:id/confirm-attendance', requireAuth, async (req: Request, res: Response): Promise<void> => {
571:   try {
572:     const bookingId = req.params.id;
573:     const booking = await prisma.booking.findUnique({
574:       where: { id: bookingId },
575:       include: { court: { include: { venue: { include: { owner: true } } } }, user: true }
576:     });
...
583:     const updated = await prisma.booking.update({
584:       where: { id: bookingId },
585:       data: { status: 'ATTENDANCE_CONFIRMED' }
586:     });
```
- **Direct Observation**: No verification that `req.user.userId === booking.userId`. Any arbitrary user can confirm attendance on behalf of another player.

#### D. Super Admin Lockout on Court Management (`src/index.ts:273-333`)
```ts
273: app.post('/api/venues/:id/courts', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
...
278:     if (!venue || venue.ownerId !== req.user!.userId) {
279:       res.status(403).json({ error: 'Forbidden' });
280:       return;
281:     }

296: app.patch('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
...
300:     if (!court || court.venue.ownerId !== req.user!.userId) {
301:       res.status(403).json({ error: 'Forbidden' });
302:       return;
303:     }

318: app.delete('/api/courts/:id', requireAuth, requireRole(['OWNER', 'ADMIN']), async (req: Request, res: Response): Promise<void> => {
...
322:     if (!court || court.venue.ownerId !== req.user!.userId) {
323:       res.status(403).json({ error: 'Forbidden' });
324:       return;
325:     }
```
- **Direct Observation**: Despite the middleware allowing `ADMIN` (`requireRole(['OWNER', 'ADMIN'])`), the handler condition strictly checks `venue.ownerId !== req.user!.userId`. Because Super Admins did not create the venue, they are blocked with `403 Forbidden` from managing or deleting courts.

#### E. Password Hash Leakage in API Responses
- **Direct Observations across endpoints**:
  1. `POST /api/auth/register` (line 129): `res.json({ user, token })` returns `user.passwordHash`.
  2. `POST /api/auth/login` (line 149): `res.json({ user, token })` returns `user.passwordHash`.
  3. `GET /api/auth/me` (line 162): `res.json(user)` returns `user.passwordHash`.
  4. `PUT /api/users/me` (line 181): `res.json(user)` returns `user.passwordHash`.
  5. `GET /api/admin/users` (line 486): `res.json(users)` returns all platform users with `passwordHash`.
  6. `GET /api/admin/venues` (line 494): `include: { owner: true }` returns `venue.owner.passwordHash`.

---

### 1.3 Firebase Admin v14 Modular Import Breakdown
**Target File**: `backend/src/index.ts:47-54, 398-405, 547-562, 597-604, 641-648`
```ts
47: import * as admin from 'firebase-admin';
48: 
49: try {
50:   const serviceAccount = require('../../firebase-admin.json');
51:   if (!admin.apps.length) {
52:     admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
53:   }
54: } catch (e) {}
```
- **Direct Observations**:
  1. In `firebase-admin` v14.4.0 (`backend/node_modules/firebase-admin/lib/app/index.d.ts`), default exports `admin.apps` and `admin.credential` are undefined.
  2. Modular subpath exports (`firebase-admin/app`, `firebase-admin/messaging`) are mandatory in v14:
     - `initializeApp`, `cert`, `getApps` are in `firebase-admin/app`.
     - `getMessaging` is in `firebase-admin/messaging`.
  3. File path `require('../../firebase-admin.json')` attempts to load from `c:\Users\MoBadawy\Desktop\firebase-admin.json` which does not exist (the actual credential file is at `backend/firebase-admin.json`). The initialization fails silently inside `catch (e) {}`.
  4. Calls to `admin.messaging().send(...)` fail at runtime with `TypeError: admin.messaging is not a function`.

---

### 1.4 Multer Upload Security & Global Error Handling
**Target File**: `backend/src/index.ts:56-72, 101-113`
```ts
62: const storage = multer.diskStorage({
63:   destination: function (req, file, cb) {
64:     cb(null, uploadDir);
65:   },
66:   filename: function (req, file, cb) {
67:     const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
68:     cb(null, uniqueSuffix + path.extname(file.originalname));
69:   }
70: });
71: const upload = multer({ storage: storage });
...
101: app.post('/api/upload', requireAuth, upload.array('images', 5), (req: Request, res: Response): void => { ... });
```
- **Direct Observations**:
  1. No `limits.fileSize` configured: clients can upload arbitrarily large files, causing storage exhaustion / DoS.
  2. No `fileFilter`: clients can upload executable scripts (`.exe`, `.sh`, `.php`, `.html`), introducing remote code execution and stored XSS vectors.
  3. No Express error middleware (`app.use((err, req, res, next) => ...)`):
     - Malformed JSON payloads trigger unhandled syntax errors returned as HTML.
     - Multer limit errors (`LIMIT_FILE_SIZE`, `LIMIT_UNEXPECTED_FILE`) return default Express HTML 500 pages with raw stack traces.
     - Unmatched routes return default Express HTML `Cannot GET /api/...` rather than JSON `{ error: string }`.

---

## 2. Logic Chain

1. **Premise 1**: Acceptance Criteria R1 & R3 require zero unhandled exceptions, type-safety, clean error presentation, and production concurrency guarantees.
2. **Step 1 (Booking Concurrency)**:
   - In PostgreSQL default `READ COMMITTED` isolation level, two concurrent transactions both executing `SELECT` for overlapping intervals will neither block nor see each other's uncommitted rows.
   - If both proceed to `INSERT INTO "Booking"`, both succeed, creating an irreconcilable double-booking on the same physical court.
   - Because PostgreSQL cannot place row locks on rows that do not yet exist, locking the parent resource `Court` via `SELECT id FROM "Court" WHERE id = $1 FOR UPDATE` inside an interactive Prisma `$transaction` guarantees that all concurrent booking attempts for the *same* court are strictly serialized at the database engine level.
   - Serialized execution ensures that the second transaction's overlap query sees the committed booking of the first transaction and rejects the conflict deterministically with HTTP 400 (`هذا الموعد محجوز مسبقاً`).
   - Concurrently booking *different* courts operates independently without blocking because different `Court` rows are locked.
3. **Step 2 (Privilege & Authorization Security)**:
   - Registration endpoints must whitelist permissible roles (`PLAYER`, `OWNER`) or default to `PLAYER`. Admin accounts must only be provisioned by existing authenticated Super Admins or via seed scripts.
   - Booking state transitions must evaluate ownership context:
     - Creator: allowed to `CANCEL` only.
     - Venue Owner: allowed to `CONFIRMED`, `REJECTED`, or `CANCELLED`.
     - Super Admin: full override.
   - Attendance confirmation must be restricted to the booking creator (`req.user.userId === booking.userId`) or Super Admin.
   - Court management route guards must accept `req.user.role === 'ADMIN'` as an authorized bypass to `venue.ownerId === req.user.userId`.
   - `passwordHash` must be stripped at query time via Prisma `select` and protected by a secondary runtime serialization scrubber (`excludePassword`).
4. **Step 3 (Firebase Admin v14 Modular Migration)**:
   - `firebase-admin` v14 enforces ESM/modular subpaths. Migrating to `import { initializeApp, cert, getApps } from 'firebase-admin/app'` and `import { getMessaging } from 'firebase-admin/messaging'` restores full SDK functionality and eliminates 7 compiler errors.
   - Centralizing Firebase logic into `src/lib/firebase.ts` with multi-path credential search (`path.resolve(process.cwd(), 'firebase-admin.json')`) and safe exception boundaries prevents notification failures from crashing business transactions.
5. **Step 4 (Middleware & Error Boundaries)**:
   - Configuring Multer with `limits: { fileSize: 5 * 1024 * 1024, files: 5 }` and MIME/extension whitelist (`image/jpeg`, `image/png`, `image/webp`) prevents disk abuse.
   - Wrapping Multer invocation and registering a global 4-parameter error handler guarantees that all errors (JSON syntax errors, Multer limit violations, Prisma errors, JWT failures) return structured `{ error: string }` JSON responses.

---

## 3. Caveats

1. **Database Lock Engine**: `SELECT ... FOR UPDATE` is native to PostgreSQL. If the application is ever pointed to an in-memory SQLite database for unit tests, `FOR UPDATE` is not supported; the implementation must wrap the raw locking statement in a graceful try/catch or conditional engine check.
2. **Neon Connection Pooling**: Neon's transaction pooler (PgBouncer) supports interactive transactions (`$transaction(async (tx) => ...)`) provided queries do not rely on session-level state. Row-level locks (`FOR UPDATE`) are transaction-scoped and fully compatible with transaction-mode pooling.
3. **Push Notification Delivery**: If a device FCM token is invalid or expired, Firebase Admin throws an error with code `messaging/registration-token-not-registered`. The wrapper logs this warning and continues without disrupting the user response.

---

## 4. Conclusion & Concrete Strategy Specifications

### 4.1 Concurrency Fix: Atomic Interactive Transaction for `POST /api/bookings`
**Implementation Location**: `backend/src/controllers/bookingController.ts` (or `backend/src/index.ts`)

```ts
import { Request, Response } from 'express';
import { prisma } from '../lib/prisma';
import { sendPushNotification } from '../lib/firebase';

export async function createBooking(req: Request, res: Response): Promise<void> => {
  try {
    const { courtId, startTime, endTime, isManual } = req.body;
    const userId = req.user!.userId;

    // 1. Input Validation
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

    // 2. Atomic Transaction with Pessimistic Row Lock on Court
    const booking = await prisma.$transaction(async (tx) => {
      // Lock the court record to serialize concurrent bookings for this specific court
      try {
        await tx.$executeRaw`SELECT id FROM "Court" WHERE id = ${courtId} FOR UPDATE`;
      } catch (e) {
        // Fallback for non-PostgreSQL testing environments
      }

      // Verify Court exists
      const court = await tx.court.findUnique({
        where: { id: courtId },
        include: { venue: { include: { owner: true } } }
      });

      if (!court) {
        throw new Error('COURT_NOT_FOUND');
      }

      // Check for overlapping active bookings within the critical section
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

      // Calculate Duration and Price
      const durationHours = (eTime.getTime() - sTime.getTime()) / 3600000;
      const price = Math.round(court.pricePerHour * durationHours * 100) / 100;
      const platformFee = Math.round(price * 0.05 * 100) / 100;
      const ownerAmount = Math.round((price - platformFee) * 100) / 100;

      // Create Booking Record Atomically
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
          court: {
            include: { venue: { include: { owner: true } } }
          }
        }
      });
    }, {
      maxWait: 5000,
      timeout: 10000,
    });

    // 3. Post-Transaction Asynchronous Side Effects
    awardGamificationPoints(userId, 50).catch(err => 
      console.error('[Gamification] Error awarding points:', err)
    );

    if (booking.court.venue.owner.fcmToken) {
      sendPushNotification(
        booking.court.venue.owner.fcmToken,
        'حجز جديد! ⚽',
        `تم حجز ${booking.court.name} بتاريخ ${sTime.toLocaleDateString()}`
      ).catch(err => console.error('[FCM] Push error:', err));
    }

    res.status(201).json(booking);
  } catch (error: any) {
    if (error.message === 'COURT_NOT_FOUND') {
      res.status(404).json({ error: 'الملعب المطلوب غير موجود' });
      return;
    }
    if (error.message === 'BOOKING_OVERLAP') {
      res.status(400).json({ error: 'هذا الموعد محجوز مسبقاً' });
      return;
    }
    console.error('[Booking] Creation failed:', error);
    res.status(500).json({ error: 'فشل في إنشاء الحجز، يرجى المحاولة لاحقاً' });
  }
}
```

---

### 4.2 Authorization & Security Implementation Specifications

#### A. Registration Role Whitelist & Password Sanitization (`POST /api/auth/register`)
```ts
app.post('/api/auth/register', async (req: Request, res: Response): Promise<void> => {
  try {
    const { name, phone, password, role } = req.body;
    if (!name || !phone || !password) {
      res.status(400).json({ error: 'الاسم ورقم الهاتف وكلمة المرور مطلوبة' });
      return;
    }

    const existing = await prisma.user.findUnique({ where: { phone } });
    if (existing) {
      res.status(400).json({ error: 'رقم الهاتف مسجل بالفعل مسبقاً' });
      return;
    }

    // Security Guard: Reject ADMIN escalation attempt from unauthenticated callers
    if (role === 'ADMIN') {
      res.status(403).json({ error: 'غير مسموح بإنشاء حساب مسؤول من واجهة التسجيل العامة' });
      return;
    }

    const userRole = (role === 'OWNER') ? 'OWNER' : 'PLAYER';
    const passwordHash = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: { name, phone, passwordHash, role: userRole }
    });

    const token = jwt.sign({ userId: user.id, role: user.role }, JWT_SECRET, { expiresIn: '30d' });

    // Scrub passwordHash from output
    const { passwordHash: _, ...safeUser } = user;
    res.status(201).json({ user: safeUser, token });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'فشل في إنشاء الحساب' });
  }
});
```

#### B. Booking Status Modification Guard (`PATCH /api/bookings/:id/status`)
```ts
app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const bookingId = req.params.id as string;
    const { status } = req.body;
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
      res.status(404).json({ error: 'الحجز غير موجود' });
      return;
    }

    const isCreator = booking.userId === callerId;
    const isVenueOwner = booking.court.venue.ownerId === callerId;
    const isAdmin = callerRole === 'ADMIN';

    // Verification Guard
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

    // Notifications
    if (status === 'REJECTED') {
      await prisma.notification.create({
        data: {
          userId: booking.userId,
          title: 'تم رفض حجزك ❌',
          body: `قام المالك بإلغاء حجزك في ${booking.court.name}.`,
          type: 'BOOKING_REJECTED'
        }
      });
      if (booking.user.fcmToken) {
        sendPushNotification(booking.user.fcmToken, 'تم رفض حجزك ❌', `قام المالك بإلغاء حجزك في ${booking.court.name}.`);
      }
    } else if (status === 'CANCELLED') {
      await prisma.notification.create({
        data: {
          userId: booking.court.venue.ownerId,
          title: 'إلغاء حجز من اللاعب ❌',
          body: `قام اللاعب ${booking.user.name} بإلغاء حجزه في ${booking.court.name}.`,
          type: 'BOOKING_CANCELLED'
        }
      });
      if (booking.court.venue.owner.fcmToken) {
        sendPushNotification(booking.court.venue.owner.fcmToken, 'إلغاء حجز من اللاعب ❌', `قام اللاعب ${booking.user.name} بإلغاء حجزه في ${booking.court.name}.`);
      }
    }

    res.json(updated);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'فشل في تحديث حالة الحجز' });
  }
});
```

#### C. Attendance Confirmation Guard (`POST /api/bookings/:id/confirm-attendance`)
```ts
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
      res.status(404).json({ error: 'الحجز غير موجود' });
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
        body: `قام اللاعب ${booking.user.name} بتأكيد حضوره لحجز ${booking.court.name}`,
        type: 'ATTENDANCE_CONFIRMED'
      }
    });

    if (booking.court.venue.owner.fcmToken) {
      sendPushNotification(
        booking.court.venue.owner.fcmToken,
        'تأكيد حضور اللاعب ✅',
        `قام اللاعب ${booking.user.name} بتأكيد حضوره لحجز ${booking.court.name}`
      );
    }

    res.json(updated);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'فشل في تأكيد الحضور' });
  }
});
```

#### D. Super Admin Court Management Override
In `POST /api/venues/:id/courts`, `PATCH /api/courts/:id`, and `DELETE /api/courts/:id`:
```ts
// In POST /api/venues/:id/courts:
const venue = await prisma.venue.findUnique({ where: { id: venueId } });
if (!venue) {
  res.status(404).json({ error: 'المنشأة غير موجودة' });
  return;
}
if (venue.ownerId !== req.user!.userId && req.user!.role !== 'ADMIN') {
  res.status(403).json({ error: 'غير مصرح لك بإضافة ملاعب لهذه المنشأة' });
  return;
}

// In PATCH /api/courts/:id:
const court = await prisma.court.findUnique({ where: { id: courtId }, include: { venue: true } });
if (!court) {
  res.status(404).json({ error: 'الملعب غير موجود' });
  return;
}
if (court.venue.ownerId !== req.user!.userId && req.user!.role !== 'ADMIN') {
  res.status(403).json({ error: 'غير مصرح لك بتعديل هذا الملعب' });
  return;
}

// In DELETE /api/courts/:id:
const court = await prisma.court.findUnique({ where: { id: courtId }, include: { venue: true } });
if (!court) {
  res.status(404).json({ error: 'الملعب غير موجود' });
  return;
}
if (court.venue.ownerId !== req.user!.userId && req.user!.role !== 'ADMIN') {
  res.status(403).json({ error: 'غير مصرح لك بحذف هذا الملعب' });
  return;
}
```

#### E. Password Hash Scrubbing Utility & Query Rules
Define `sanitizeUser` in `src/utils/sanitize.ts`:
```ts
export function sanitizeUser<T extends { passwordHash?: string }>(user: T): Omit<T, 'passwordHash'> {
  const { passwordHash, ...safe } = user;
  return safe;
}

export function sanitizeUsers<T extends { passwordHash?: string }>(users: T[]): Omit<T, 'passwordHash'>[] {
  return users.map(sanitizeUser);
}
```
Apply across endpoints:
- `POST /api/auth/register` & `POST /api/auth/login`: return `{ user: sanitizeUser(user), token }`.
- `GET /api/auth/me` & `PUT /api/users/me`: return `sanitizeUser(user)`.
- `GET /api/admin/users`: return `sanitizeUsers(users)`.
- `GET /api/admin/venues`:
  ```ts
  const venues = await prisma.venue.findMany({
    include: {
      owner: {
        select: { id: true, name: true, phone: true, role: true, profilePic: true }
      }
    },
    orderBy: { createdAt: 'desc' }
  });
  ```

---

### 4.3 Firebase Admin v14 Modular Integration Architecture
**Implementation Location**: `backend/src/lib/firebase.ts`

```ts
import path from 'path';
import fs from 'fs';
import { initializeApp, cert, getApps, App } from 'firebase-admin/app';
import { getMessaging, Messaging, Message, MulticastMessage } from 'firebase-admin/messaging';

let appInstance: App | null = null;
let messagingInstance: Messaging | null = null;

export function getFirebaseMessaging(): Messaging | null {
  if (messagingInstance) return messagingInstance;

  if (getApps().length > 0) {
    appInstance = getApps()[0];
    messagingInstance = getMessaging(appInstance);
    return messagingInstance;
  }

  // Robust path resolution for dev, dist, and root runs
  const candidatePaths = [
    path.resolve(process.cwd(), 'firebase-admin.json'),
    path.resolve(process.cwd(), 'backend', 'firebase-admin.json'),
    path.resolve(__dirname, '../../firebase-admin.json'),
    path.resolve(__dirname, '../firebase-admin.json')
  ];

  let credentialPath: string | null = null;
  for (const candidate of candidatePaths) {
    if (fs.existsSync(candidate)) {
      credentialPath = candidate;
      break;
    }
  }

  if (!credentialPath) {
    console.warn('[Firebase] Warning: firebase-admin.json credentials not found. Push notifications will be mocked/skipped.');
    return null;
  }

  try {
    const serviceAccount = JSON.parse(fs.readFileSync(credentialPath, 'utf8'));
    appInstance = initializeApp({
      credential: cert(serviceAccount)
    });
    messagingInstance = getMessaging(appInstance);
    console.log('[Firebase] Initialized successfully with credentials from:', credentialPath);
    return messagingInstance;
  } catch (error) {
    console.error('[Firebase] Failed to initialize Firebase Admin SDK:', error);
    return null;
  }
}

export async function sendPushNotification(
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
        }
      }
    };
    await messaging.send(message);
    return true;
  } catch (error: any) {
    console.warn(`[Firebase] Failed to send push notification (${error.code || error.message})`);
    return false;
  }
}

export async function sendMulticastNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ successCount: number; failureCount: number }> {
  const validTokens = tokens.filter(Boolean);
  if (validTokens.length === 0) return { successCount: 0, failureCount: 0 };

  const messaging = getFirebaseMessaging();
  if (!messaging) return { successCount: 0, failureCount: validTokens.length };

  try {
    const response = await messaging.sendEachForMulticast({
      tokens: validTokens,
      notification: { title, body },
      data: data || {}
    });
    return {
      successCount: response.successCount,
      failureCount: response.failureCount
    };
  } catch (error) {
    console.error('[Firebase] Multicast push error:', error);
    return { successCount: 0, failureCount: validTokens.length };
  }
}
```

---

### 4.4 Express Global JSON Error Handler & Multer Security Middleware

#### A. Multer Image Upload Security Middleware (`backend/src/middlewares/upload.ts`)
```ts
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { Request, Response, NextFunction } from 'express';

const uploadDir = path.resolve(process.cwd(), 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, uploadDir);
  },
  filename: (_req, file, cb) => {
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${uniqueSuffix}${ext}`);
  }
});

const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp']);
const ALLOWED_EXTENSIONS = new Set(['.jpg', '.jpeg', '.png', '.webp']);

const multerInstance = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024, // 5 MB per file limit
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

export function handleImageUpload(req: Request, res: Response, next: NextFunction): void {
  multerInstance.array('images', 5)(req, res, (err: any) => {
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
    next();
  });
}
```

#### B. Global Error Handler & 404 Middleware (`backend/src/middlewares/errorHandler.ts`)
```ts
import { Request, Response, NextFunction, ErrorRequestHandler } from 'express';
import multer from 'multer';
import { Prisma } from '@prisma/client';

export class AppError extends Error {
  public readonly statusCode: number;

  constructor(statusCode: number, message: string) {
    super(message);
    this.statusCode = statusCode;
    Object.setPrototypeOf(this, AppError.prototype);
  }
}

export const globalErrorHandler: ErrorRequestHandler = (
  err: any,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
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

  // 3. Custom Application Errors
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ error: err.message });
    return;
  }

  // 4. Prisma Known Database Request Errors
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

  // 5. JWT Authentication Errors
  if (err.name === 'JsonWebTokenError') {
    res.status(401).json({ error: 'رمز الدخول غير صالح (Invalid token)' });
    return;
  }
  if (err.name === 'TokenExpiredError') {
    res.status(401).json({ error: 'انتهت صلاحية الجلسة، برجاء تسجيل الدخول مجدداً' });
    return;
  }

  // 6. Generic Fallback
  const status = typeof err.statusCode === 'number' ? err.statusCode :
                 typeof err.status === 'number' ? err.status : 500;

  const message = status < 500 && err.message 
    ? err.message 
    : 'حدث خطأ في الخادم، يرجى المحاولة لاحقاً';

  res.status(status).json({ error: message });
};

export function notFoundHandler(req: Request, res: Response): void {
  res.status(404).json({ error: `المسار غير موجود: ${req.method} ${req.originalUrl}` });
}
```

---

## 5. Verification Method

### 5.1 Verification of Concurrency Protection (Double-Booking Race Condition)
Execute two simultaneous curl/fetch requests attempting to book the identical court and slot:
```bash
# Terminal 1:
curl -X POST http://localhost:3001/api/bookings \
  -H "Authorization: Bearer $PLAYER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"courtId":"<court_id>","startTime":"2026-10-01T18:00:00Z","endTime":"2026-10-01T19:00:00Z"}'

# Terminal 2 (fired concurrently):
curl -X POST http://localhost:3001/api/bookings \
  -H "Authorization: Bearer $PLAYER_TOKEN_2" \
  -H "Content-Type: application/json" \
  -d '{"courtId":"<court_id>","startTime":"2026-10-01T18:00:00Z","endTime":"2026-10-01T19:00:00Z"}'
```
- **Expected Result**: Exactly one request returns HTTP `201 Created`; the second request returns HTTP `400 Bad Request` with `{"error":"هذا الموعد محجوز مسبقاً"}`. Zero duplicate bookings created in DB.

### 5.2 Verification of Privilege Escalation Prevention
Attempt to register with role `ADMIN`:
```bash
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Attacker","phone":"01099999999","password":"password123","role":"ADMIN"}'
```
- **Expected Result**: Returns HTTP `403 Forbidden` (`{"error":"غير مسموح بإنشاء حساب مسؤول من واجهة التسجيل العامة"}`) and no admin account is created.

### 5.3 Verification of Password Hash Scrubbing
Query any user endpoint:
```bash
curl -X GET http://localhost:3001/api/auth/me \
  -H "Authorization: Bearer $PLAYER_TOKEN"
```
- **Expected Result**: Returned JSON must contain `id, phone, name, role, points, level`, and must NOT contain the `passwordHash` key.

### 5.4 Verification of Multer Limits & Global Error Handler
Send a payload of 6 files or a file larger than 5MB to `POST /api/upload`:
- **Expected Result**: Returns HTTP `400 Bad Request` with `{"error":"حجم الصورة يجب ألا يتجاوز 5 ميجابايت"}` or `{"error":"الحد الأقصى المسموح به هو 5 صور"}`. Never returns HTML stack trace.
