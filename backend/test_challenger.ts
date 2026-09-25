import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import http from 'http';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev-only';

function request(
  port: number,
  method: string,
  path: string,
  body?: any,
  token?: string,
  rawBody?: string
): Promise<{ status: number; body: any; headers: http.IncomingHttpHeaders }> {
  return new Promise((resolve, reject) => {
    const postData = rawBody !== undefined ? rawBody : (body !== undefined ? JSON.stringify(body) : '');
    const headers: http.OutgoingHttpHeaders = {
      'Content-Type': 'application/json',
    };
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
    if (postData) {
      headers['Content-Length'] = Buffer.byteLength(postData);
    }

    const req = http.request(
      {
        hostname: '127.0.0.1',
        port,
        path,
        method,
        headers,
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          let parsedBody: any;
          try {
            parsedBody = JSON.parse(data);
          } catch {
            parsedBody = data;
          }
          resolve({ status: res.statusCode || 500, body: parsedBody, headers: res.headers });
        });
      }
    );

    req.on('error', reject);
    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

async function runChallengerSuite() {
  console.log('================================================================');
  console.log('   EMPIRICAL CHALLENGER ADVERSARIAL VERIFICATION HARNESS (M1)   ');
  console.log('================================================================\n');

  const testPort = 3095;
  process.env.PORT = String(testPort);

  // Allow index.ts to listen on 3095
  await import('./src/index');
  await new Promise((r) => setTimeout(r, 600));

  let passed = 0;
  let failed = 0;
  const failures: { test: string; detail: any }[] = [];

  function assert(condition: boolean, testName: string, detail?: any) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName}`);
      if (detail !== undefined) console.error('       Detail:', typeof detail === 'object' ? JSON.stringify(detail) : detail);
      failed++;
      failures.push({ test: testName, detail });
    }
  }

  // Unique dedicated test identities
  const P_ADMIN = '01888888001';
  const P_OWNER1 = '01888888002';
  const P_OWNER2 = '01888888003';
  const P_PLAYER1 = '01888888004';
  const P_PLAYER2 = '01888888005';
  const P_ATTACKER = '01888888006';

  const testPhones = [P_ADMIN, P_OWNER1, P_OWNER2, P_PLAYER1, P_PLAYER2, P_ATTACKER];

  async function cleanup() {
    try {
      const users = await prisma.user.findMany({ where: { phone: { in: testPhones } }, select: { id: true } });
      const userIds = users.map((u) => u.id);
      if (userIds.length > 0) {
        await prisma.notification.deleteMany({ where: { userId: { in: userIds } } });
        await prisma.message.deleteMany({ where: { senderId: { in: userIds } } });
        await prisma.booking.deleteMany({ where: { userId: { in: userIds } } });
        await prisma.matchRequest.deleteMany({ where: { creatorId: { in: userIds } } });
        await prisma.review.deleteMany({ where: { userId: { in: userIds } } });

        const venues = await prisma.venue.findMany({ where: { ownerId: { in: userIds } }, select: { id: true } });
        const venueIds = venues.map((v) => v.id);
        if (venueIds.length > 0) {
          await prisma.booking.deleteMany({ where: { court: { venueId: { in: venueIds } } } });
          await prisma.court.deleteMany({ where: { venueId: { in: venueIds } } });
          await prisma.venue.deleteMany({ where: { id: { in: venueIds } } });
        }
        await prisma.user.deleteMany({ where: { id: { in: userIds } } });
      }
    } catch (e) {
      console.warn('Cleanup warning:', e);
    }
  }

  try {
    await cleanup();

    // =========================================================================
    // SECTION 1: PRIVILEGE ESCALATION ADVERSARIAL STRESS
    // =========================================================================
    console.log('\n--- SECTION 1: PRIVILEGE ESCALATION ADVERSARIAL STRESS ---');

    // 1.1 Direct ADMIN escalation attempt
    const r1_1 = await request(testPort, 'POST', '/api/auth/register', {
      name: 'Adversary Admin',
      phone: P_ATTACKER,
      password: 'password123',
      role: 'ADMIN',
    });
    assert(r1_1.status === 403, '1.1 Public registration with role: "ADMIN" returns 403 Forbidden', r1_1.body);

    const checkAdminInDb = await prisma.user.findUnique({ where: { phone: P_ATTACKER } });
    assert(checkAdminInDb === null, '1.2 User with role: "ADMIN" was NOT inserted into database');

    // 1.2 Lowercase "admin" attempt
    const r1_2 = await request(testPort, 'POST', '/api/auth/register', {
      name: 'Adversary admin',
      phone: P_ATTACKER,
      password: 'password123',
      role: 'admin',
    });
    assert(r1_2.status === 201, '1.3 Registration with role: "admin" succeeds with 201', r1_2.body);
    const checkAdminLower = await prisma.user.findUnique({ where: { phone: P_ATTACKER } });
    assert(checkAdminLower?.role === 'PLAYER', '1.4 Role in database fell back to "PLAYER" (not admin or ADMIN)', checkAdminLower?.role);

    // 1.3 Attacker tries to access admin-only endpoint with this token
    const attackerToken = r1_2.body.token;
    const r1_3 = await request(testPort, 'GET', '/api/admin/stats', undefined, attackerToken);
    assert(r1_3.status === 403, '1.5 Attacker with role: "admin" cannot access /api/admin/stats (403 Forbidden)', r1_3.body);

    // Clean up attacker before next tests
    await prisma.user.delete({ where: { phone: P_ATTACKER } });

    // =========================================================================
    // SECTION 2: CONCURRENCY & DOUBLE-BOOKING LOCKING STRESS
    // =========================================================================
    console.log('\n--- SECTION 2: CONCURRENCY & DOUBLE-BOOKING LOCKING STRESS ---');

    const pwdHash = await bcrypt.hash('password123', 10);
    const owner1 = await prisma.user.create({
      data: { name: 'Challenger Owner 1', phone: P_OWNER1, passwordHash: pwdHash, role: 'OWNER' },
    });
    const owner1Token = jwt.sign({ userId: owner1.id, role: owner1.role }, JWT_SECRET);

    const player1 = await prisma.user.create({
      data: { name: 'Challenger Player 1', phone: P_PLAYER1, passwordHash: pwdHash, role: 'PLAYER' },
    });
    const player1Token = jwt.sign({ userId: player1.id, role: player1.role }, JWT_SECRET);

    const player2 = await prisma.user.create({
      data: { name: 'Challenger Player 2', phone: P_PLAYER2, passwordHash: pwdHash, role: 'PLAYER' },
    });
    const player2Token = jwt.sign({ userId: player2.id, role: player2.role }, JWT_SECRET);

    const admin = await prisma.user.create({
      data: { name: 'Challenger Admin', phone: P_ADMIN, passwordHash: pwdHash, role: 'ADMIN' },
    });
    const adminToken = jwt.sign({ userId: admin.id, role: admin.role }, JWT_SECRET);

    const venue1 = await prisma.venue.create({
      data: {
        name: 'Arena Challenger',
        category: 'كرة قدم',
        description: 'Test arena',
        location: 'Cairo',
        images: '["arena.jpg"]',
        ownerId: owner1.id,
      },
    });

    const court1 = await prisma.court.create({
      data: {
        venueId: venue1.id,
        name: 'Court Alpha',
        category: 'خماسي',
        pricePerHour: 100,
        images: '["court.jpg"]',
        amenities: '["lights"]',
      },
    });

    // 2.1 Concurrency Race: Two simultaneous requests for the EXACT same slot
    const slot1Start = new Date(Date.now() + 3600000 * 50); // 50h in future
    const slot1End = new Date(Date.now() + 3600000 * 51);

    const [race1, race2] = await Promise.all([
      request(testPort, 'POST', '/api/bookings', { courtId: court1.id, startTime: slot1Start.toISOString(), endTime: slot1End.toISOString() }, player1Token),
      request(testPort, 'POST', '/api/bookings', { courtId: court1.id, startTime: slot1Start.toISOString(), endTime: slot1End.toISOString() }, player2Token),
    ]);

    const raceStatuses = [race1.status, race2.status].sort();
    assert(
      raceStatuses[0] === 201 && raceStatuses[1] === 400,
      `2.1 Two concurrent requests: exactly 1 succeeds (201) and 1 is rejected (400) (actual: [${race1.status}, ${race2.status}])`,
      { r1: race1.body, r2: race2.body }
    );

    // Verify DB count for slot1
    const slot1DbBookings = await prisma.booking.findMany({
      where: {
        courtId: court1.id,
        startTime: { gte: new Date(slot1Start.getTime() - 1000), lte: new Date(slot1Start.getTime() + 1000) },
      },
    });
    assert(slot1DbBookings.length === 1, `2.2 Exactly 1 booking committed to database for slot 1 (actual: ${slot1DbBookings.length})`);

    // 2.3 Partial Overlap: Starts during existing booking
    // Existing: [50h, 51h]. Attempt: [50.5h, 51.5h]
    const overlap1Start = new Date(slot1Start.getTime() + 1800000);
    const overlap1End = new Date(slot1End.getTime() + 1800000);
    const rOverlap1 = await request(
      testPort,
      'POST',
      '/api/bookings',
      { courtId: court1.id, startTime: overlap1Start.toISOString(), endTime: overlap1End.toISOString() },
      player2Token
    );
    assert(
      rOverlap1.status === 400 && rOverlap1.body.error === 'هذا الموعد محجوز مسبقاً',
      '2.3 Overlapping start rejected with 400 ("هذا الموعد محجوز مسبقاً")',
      rOverlap1.body
    );

    // 2.4 Partial Overlap: Ends during existing booking
    // Attempt: [49.5h, 50.5h]
    const overlap2Start = new Date(slot1Start.getTime() - 1800000);
    const overlap2End = new Date(slot1Start.getTime() + 1800000);
    const rOverlap2 = await request(
      testPort,
      'POST',
      '/api/bookings',
      { courtId: court1.id, startTime: overlap2Start.toISOString(), endTime: overlap2End.toISOString() },
      player2Token
    );
    assert(
      rOverlap2.status === 400 && rOverlap2.body.error === 'هذا الموعد محجوز مسبقاً',
      '2.4 Overlapping end rejected with 400 ("هذا الموعد محجوز مسبقاً")',
      rOverlap2.body
    );

    // 2.5 Enclosing Overlap: Envelops existing booking [49h, 52h]
    const overlap3Start = new Date(slot1Start.getTime() - 3600000);
    const overlap3End = new Date(slot1End.getTime() + 3600000);
    const rOverlap3 = await request(
      testPort,
      'POST',
      '/api/bookings',
      { courtId: court1.id, startTime: overlap3Start.toISOString(), endTime: overlap3End.toISOString() },
      player2Token
    );
    assert(
      rOverlap3.status === 400 && rOverlap3.body.error === 'هذا الموعد محجوز مسبقاً',
      '2.5 Enclosing overlap rejected with 400 ("هذا الموعد محجوز مسبقاً")',
      rOverlap3.body
    );

    // 2.6 Adjacent Slot: Touching boundary immediately after [51h, 52h] (Should SUCCEED)
    const adjacentStart = new Date(slot1End.getTime());
    const adjacentEnd = new Date(slot1End.getTime() + 3600000);
    const rAdjacent = await request(
      testPort,
      'POST',
      '/api/bookings',
      { courtId: court1.id, startTime: adjacentStart.toISOString(), endTime: adjacentEnd.toISOString() },
      player2Token
    );
    assert(rAdjacent.status === 201, '2.6 Adjacent non-overlapping slot succeeds with 201', rAdjacent.body);

    // 2.7 Inverted time range: startTime >= endTime
    const rInverted = await request(
      testPort,
      'POST',
      '/api/bookings',
      { courtId: court1.id, startTime: slot1End.toISOString(), endTime: slot1Start.toISOString() },
      player1Token
    );
    assert(rInverted.status === 400 && rInverted.body.error === 'وقت بداية الحجز يجب أن يكون قبل وقت النهاية', '2.7 Inverted time range returns 400', rInverted.body);

    // 2.8 Booking in the past
    const pastStart = new Date(Date.now() - 3600000 * 24);
    const pastEnd = new Date(Date.now() - 3600000 * 23);
    const rPast = await request(
      testPort,
      'POST',
      '/api/bookings',
      { courtId: court1.id, startTime: pastStart.toISOString(), endTime: pastEnd.toISOString() },
      player1Token
    );
    assert(rPast.status === 400 && rPast.body.error === 'لا يمكن حجز موعد في الماضي', '2.8 Booking in the past without isManual returns 400', rPast.body);

    // =========================================================================
    // SECTION 3: BOOKING STATUS & ATTENDANCE AUTHORIZATION (IDOR)
    // =========================================================================
    console.log('\n--- SECTION 3: BOOKING STATUS & ATTENDANCE AUTHORIZATION (IDOR) ---');

    // Create a fresh dedicated booking for authorization testing
    const authSlotStart = new Date(Date.now() + 3600000 * 60);
    const authSlotEnd = new Date(Date.now() + 3600000 * 61);
    const bookingRes = await request(
      testPort,
      'POST',
      '/api/bookings',
      { courtId: court1.id, startTime: authSlotStart.toISOString(), endTime: authSlotEnd.toISOString() },
      player1Token
    );
    assert(bookingRes.status === 201, '3.0 Dedicated test booking created for Player 1', bookingRes.body);
    const targetBooking = bookingRes.body;

    // 3.1 Unauthorized player (Player 2) tries to modify Player 1's booking to CONFIRMED
    const rAuth1 = await request(
      testPort,
      'PATCH',
      `/api/bookings/${targetBooking.id}/status`,
      { status: 'CONFIRMED' },
      player2Token
    );
    assert(rAuth1.status === 403, '3.1 Unauthorized player cannot modify booking status (403 Forbidden)', rAuth1.body);

    // 3.2 Unauthorized player (Player 2) tries to CANCEL Player 1's booking
    const rAuth2 = await request(
      testPort,
      'PATCH',
      `/api/bookings/${targetBooking.id}/status`,
      { status: 'CANCELLED' },
      player2Token
    );
    assert(rAuth2.status === 403, '3.2 Unauthorized player cannot cancel another user\'s booking (403 Forbidden)', rAuth2.body);

    // 3.3 Unauthenticated caller tries to modify booking status
    const rAuth3 = await request(testPort, 'PATCH', `/api/bookings/${targetBooking.id}/status`, { status: 'CANCELLED' });
    assert(rAuth3.status === 401, '3.3 Unauthenticated status modification returns 401 Unauthorized', rAuth3.body);

    // 3.4 Booking creator (Player 1) tries to force status to CONFIRMED (creator only permitted CANCELLED)
    const rAuth4 = await request(
      testPort,
      'PATCH',
      `/api/bookings/${targetBooking.id}/status`,
      { status: 'CONFIRMED' },
      player1Token
    );
    assert(rAuth4.status === 403, '3.4 Booking creator cannot force CONFIRMED status (403 Forbidden)', rAuth4.body);

    // 3.5 Unauthorized player (Player 2) tries to confirm attendance on Player 1's booking
    const rAuth5 = await request(
      testPort,
      'POST',
      `/api/bookings/${targetBooking.id}/confirm-attendance`,
      undefined,
      player2Token
    );
    assert(rAuth5.status === 403, '3.5 Unauthorized player cannot confirm attendance (403 Forbidden)', rAuth5.body);

    // 3.6 Booking creator (Player 1) confirms attendance
    const rAuth6 = await request(
      testPort,
      'POST',
      `/api/bookings/${targetBooking.id}/confirm-attendance`,
      undefined,
      player1Token
    );
    assert(
      rAuth6.status === 200 && rAuth6.body.status === 'ATTENDANCE_CONFIRMED',
      '3.6 Booking creator confirms attendance successfully (200 OK, status: ATTENDANCE_CONFIRMED)',
      rAuth6.body
    );

    // 3.7 Booking creator cancels their own booking
    const rAuth7 = await request(
      testPort,
      'PATCH',
      `/api/bookings/${targetBooking.id}/status`,
      { status: 'CANCELLED' },
      player1Token
    );
    assert(
      rAuth7.status === 200 && rAuth7.body.status === 'CANCELLED',
      '3.7 Booking creator successfully cancels booking (200 OK, status: CANCELLED)',
      rAuth7.body
    );

    // 3.8 Attendance confirmation on a CANCELLED booking fails with 400
    const rAuth8 = await request(
      testPort,
      'POST',
      `/api/bookings/${targetBooking.id}/confirm-attendance`,
      undefined,
      player1Token
    );
    assert(rAuth8.status === 400, '3.8 Confirming attendance on CANCELLED booking returns 400 Bad Request', rAuth8.body);

    // 3.9 Venue Owner can modify booking status back to CONFIRMED
    const rAuth9 = await request(
      testPort,
      'PATCH',
      `/api/bookings/${targetBooking.id}/status`,
      { status: 'CONFIRMED' },
      owner1Token
    );
    assert(
      rAuth9.status === 200 && rAuth9.body.status === 'CONFIRMED',
      '3.9 Venue Owner modifies booking status to CONFIRMED (200 OK)',
      rAuth9.body
    );

    // =========================================================================
    // SECTION 4: VENUE & COURT OWNERSHIP ENFORCEMENTS & SUPER ADMIN
    // =========================================================================
    console.log('\n--- SECTION 4: VENUE & COURT OWNERSHIP ENFORCEMENTS ---');

    // 4.1 Player attempts to add court to Owner 1's venue
    const rCourt1 = await request(
      testPort,
      'POST',
      `/api/venues/${venue1.id}/courts`,
      { name: 'Unauthorized Court', category: 'خماسي', pricePerHour: 80 },
      player1Token
    );
    assert(rCourt1.status === 403, '4.1 Player cannot add court to venue (403 Forbidden)', rCourt1.body);

    // Create Owner 2
    const owner2 = await prisma.user.create({
      data: { name: 'Challenger Owner 2', phone: P_OWNER2, passwordHash: pwdHash, role: 'OWNER' },
    });
    const owner2Token = jwt.sign({ userId: owner2.id, role: owner2.role }, JWT_SECRET);

    // 4.2 Non-owning Owner 2 attempts to add court to Owner 1's venue
    const rCourt2 = await request(
      testPort,
      'POST',
      `/api/venues/${venue1.id}/courts`,
      { name: 'Hijacked Court', category: 'خماسي', pricePerHour: 80 },
      owner2Token
    );
    assert(rCourt2.status === 403, '4.2 Non-owning Owner cannot add court to another owner\'s venue (403 Forbidden)', rCourt2.body);

    // 4.3 Super Admin adds court to Owner 1's venue
    const rCourt3 = await request(
      testPort,
      'POST',
      `/api/venues/${venue1.id}/courts`,
      { name: 'Admin Added Court', category: 'بادل', pricePerHour: 200 },
      adminToken
    );
    assert(rCourt3.status === 201 && rCourt3.body.name === 'Admin Added Court', '4.3 Super Admin can add court to any venue (201 Created)', rCourt3.body);
    const adminCourtId = rCourt3.body.id;

    // 4.4 Non-owning Owner 2 cannot delete court
    const rCourt4 = await request(testPort, 'DELETE', `/api/courts/${adminCourtId}`, undefined, owner2Token);
    assert(rCourt4.status === 403, '4.4 Non-owning Owner cannot delete court (403 Forbidden)', rCourt4.body);

    // 4.5 Super Admin CAN delete court
    const rCourt5 = await request(testPort, 'DELETE', `/api/courts/${adminCourtId}`, undefined, adminToken);
    assert(rCourt5.status === 200, '4.5 Super Admin can delete court (200 OK)', rCourt5.body);

    // =========================================================================
    // SECTION 5: ADMIN ROUTE ACCESS & BAN CONTROLS
    // =========================================================================
    console.log('\n--- SECTION 5: ADMIN ROUTE ACCESS & BAN CONTROLS ---');

    // 5.1 Player cannot toggle ban
    const rBan1 = await request(testPort, 'POST', `/api/admin/users/${player2.id}/toggle-ban`, undefined, player1Token);
    assert(rBan1.status === 403, '5.1 Non-admin cannot toggle ban on user (403 Forbidden)', rBan1.body);

    // 5.2 Admin cannot self-ban
    const rBan2 = await request(testPort, 'POST', `/api/admin/users/${admin.id}/toggle-ban`, undefined, adminToken);
    assert(rBan2.status === 400 && rBan2.body.error === 'لا يمكنك حظر حسابك الخاص', '5.2 Admin cannot ban self (400 Bad Request)', rBan2.body);

    // 5.3 Admin bans Player 2
    const rBan3 = await request(testPort, 'POST', `/api/admin/users/${player2.id}/toggle-ban`, undefined, adminToken);
    assert(rBan3.status === 200 && rBan3.body.isActive === false, '5.3 Admin successfully bans Player 2 (200 OK, isActive: false)', rBan3.body);

    // 5.4 Banned user login rejected
    const rBan4 = await request(testPort, 'POST', '/api/auth/login', { phone: P_PLAYER2, password: 'password123' });
    assert(rBan4.status === 401 && rBan4.body.error === 'Invalid credentials or account suspended', '5.4 Banned user login is rejected with 401', rBan4.body);

    // 5.5 Admin unbans Player 2
    const rBan5 = await request(testPort, 'POST', `/api/admin/users/${player2.id}/toggle-ban`, undefined, adminToken);
    assert(rBan5.status === 200 && rBan5.body.isActive === true, '5.5 Admin unbans Player 2 (200 OK, isActive: true)', rBan5.body);

    // =========================================================================
    // SECTION 6: GLOBAL ERROR HANDLING & PASSWORD SANITIZATION
    // =========================================================================
    console.log('\n--- SECTION 6: GLOBAL ERROR HANDLING & PASSWORD SANITIZATION ---');

    // 6.1 Malformed JSON payload
    const rErr1 = await request(testPort, 'POST', '/api/auth/login', undefined, undefined, '{"invalid_json:');
    assert(
      rErr1.status === 400 && rErr1.body.error === 'صيغة البيانات غير صحيحة (Malformed JSON)',
      '6.1 Malformed JSON returns 400 JSON error without HTML or stack trace',
      rErr1.body
    );

    // 6.2 404 Route
    const rErr2 = await request(testPort, 'GET', '/api/non-existent-challenger-route');
    assert(rErr2.status === 404 && typeof rErr2.body.error === 'string', '6.2 Non-existent route returns 404 JSON error without HTML', rErr2.body);

    // 6.3 Password hash sanitization audit
    const rMe = await request(testPort, 'GET', '/api/auth/me', undefined, player1Token);
    assert(rMe.body?.passwordHash === undefined, '6.3 GET /api/auth/me does not leak passwordHash');

    const rAdminUsers = await request(testPort, 'GET', '/api/admin/users', undefined, adminToken);
    const hashLeaked = Array.isArray(rAdminUsers.body) && rAdminUsers.body.some((u: any) => u.passwordHash !== undefined);
    assert(!hashLeaked, '6.4 GET /api/admin/users does not leak passwordHash');

    // Clean up
    await cleanup();

    console.log('\n================================================================');
    console.log(`   CHALLENGER HARNESS RESULT: ${passed} PASSED, ${failed} FAILED`);
    console.log('================================================================');

    if (failed > 0) {
      console.error('\nFailure Summary:');
      for (const f of failures) {
        console.error(`- ${f.test}: ${JSON.stringify(f.detail)}`);
      }
    }

    await prisma.$disconnect();
    process.exit(failed > 0 ? 1 : 0);
  } catch (err: any) {
    console.error('Fatal Harness Exception:', err);
    await cleanup();
    await prisma.$disconnect();
    process.exit(1);
  }
}

runChallengerSuite();
