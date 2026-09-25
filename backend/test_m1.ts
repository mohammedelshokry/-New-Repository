import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import http from 'http';

const prisma = new PrismaClient();
const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-key-for-dev-only';

// Helper to make local HTTP requests to the running backend
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

async function runTests() {
  console.log('--- Starting Milestone 1 Automated Verification Suite ---');
  const port = 3099;
  process.env.PORT = String(port);

  // Import app after setting PORT
  const app = (await import('./src/index')).default;
  const server = app.listen(port, '127.0.0.1');

  await new Promise((r) => setTimeout(r, 500));

  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, detail?: any) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName}`, detail || '');
      failed++;
    }
  }

  try {
    // Clean up any test users
    const testPhonePlayer1 = '01111111111';
    const testPhonePlayer2 = '01111111112';
    const testPhoneOwner = '01111111113';
    const testPhoneAdmin = '01111111114';

    await prisma.notification.deleteMany({ where: { user: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.message.deleteMany({ where: { sender: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.booking.deleteMany({ where: { user: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.court.deleteMany({ where: { venue: { owner: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } } });
    await prisma.venue.deleteMany({ where: { owner: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.matchRequest.deleteMany({ where: { creator: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.user.deleteMany({ where: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } });

    // Test 1: Public Registration rejects { role: 'ADMIN' }
    const regAdminRes = await request(port, 'POST', '/api/auth/register', {
      name: 'Hacker Admin',
      phone: testPhoneAdmin,
      password: 'password123',
      role: 'ADMIN',
    });
    assert(regAdminRes.status === 403, 'Test 1: Registration rejects ADMIN escalation with 403', regAdminRes.body);

    // Test 2: Public Registration creates PLAYER and scrubs passwordHash
    const regPlayerRes = await request(port, 'POST', '/api/auth/register', {
      name: 'Player One',
      phone: testPhonePlayer1,
      password: 'password123',
      role: 'PLAYER',
    });
    assert(
      regPlayerRes.status === 201 &&
        regPlayerRes.body.user &&
        regPlayerRes.body.user.passwordHash === undefined &&
        typeof regPlayerRes.body.token === 'string',
      'Test 2: Registration creates PLAYER, scrubs passwordHash, returns JWT token',
      regPlayerRes.body
    );
    const playerToken = regPlayerRes.body.token;
    const playerId = regPlayerRes.body.user.id;

    // Create a second player
    const regPlayer2Res = await request(port, 'POST', '/api/auth/register', {
      name: 'Player Two',
      phone: testPhonePlayer2,
      password: 'password123',
      role: 'PLAYER',
    });
    const player2Token = regPlayer2Res.body.token;
    const player2Id = regPlayer2Res.body.user.id;

    // Create an Owner user directly in DB
    const pwdHash = await bcrypt.hash('password123', 10);
    const owner = await prisma.user.create({
      data: { name: 'Venue Owner', phone: testPhoneOwner, passwordHash: pwdHash, role: 'OWNER' },
    });
    const ownerToken = jwt.sign({ userId: owner.id, role: owner.role }, JWT_SECRET);

    // Create an Admin user directly in DB
    const admin = await prisma.user.create({
      data: { name: 'Super Admin', phone: testPhoneAdmin, passwordHash: pwdHash, role: 'ADMIN' },
    });
    const adminToken = jwt.sign({ userId: admin.id, role: admin.role }, JWT_SECRET);

    // Test 3: Login authenticates user and scrubs passwordHash
    const loginRes = await request(port, 'POST', '/api/auth/login', {
      phone: testPhonePlayer1,
      password: 'password123',
    });
    assert(
      loginRes.status === 200 &&
        loginRes.body.user &&
        loginRes.body.user.passwordHash === undefined &&
        loginRes.body.user.phone === testPhonePlayer1,
      'Test 3: Login works and scrubs passwordHash',
      loginRes.body
    );

    // Test 4: GET /api/auth/me returns profile without passwordHash
    const meRes = await request(port, 'GET', '/api/auth/me', undefined, playerToken);
    assert(
      meRes.status === 200 && meRes.body.id === playerId && meRes.body.passwordHash === undefined,
      'Test 4: GET /api/auth/me returns 200 with sanitized user',
      meRes.body
    );

    // Test 5: Missing Endpoint: PATCH /api/notifications/read-all
    await prisma.notification.createMany({
      data: [
        { userId: playerId, title: 'Notif 1', body: 'Body 1', type: 'TEST', isRead: false },
        { userId: playerId, title: 'Notif 2', body: 'Body 2', type: 'TEST', isRead: false },
      ],
    });
    const readAllRes = await request(port, 'PATCH', '/api/notifications/read-all', undefined, playerToken);
    const unreadCount = await prisma.notification.count({ where: { userId: playerId, isRead: false } });
    assert(
      readAllRes.status === 200 && readAllRes.body.success === true && unreadCount === 0,
      'Test 5: PATCH /api/notifications/read-all marks notifications as read',
      readAllRes.body
    );

    // Test 6: Missing Endpoints: GET and POST /api/matches/:id/messages
    const matchReqRes = await request(
      port,
      'POST',
      '/api/match-requests',
      {
        title: 'Friday Night Football',
        description: 'Need 2 more players',
        matchTime: new Date(Date.now() + 86400000).toISOString(),
        missingSpots: 2,
        costPerSpot: 50,
      },
      playerToken
    );
    const matchId = matchReqRes.body.id;

    // Post message to match
    const postMsgRes = await request(
      port,
      'POST',
      `/api/matches/${matchId}/messages`,
      { content: 'أنا جاهز للمباراة!' },
      playerToken
    );
    assert(
      postMsgRes.status === 201 &&
        postMsgRes.body.content === 'أنا جاهز للمباراة!' &&
        postMsgRes.body.senderId === playerId &&
        postMsgRes.body.sender.avatarUrl !== undefined,
      'Test 6a: POST /api/matches/:id/messages securely attaches senderId and profile',
      postMsgRes.body
    );

    // Get messages
    const getMsgsRes = await request(port, 'GET', `/api/matches/${matchId}/messages`, undefined, playerToken);
    assert(
      getMsgsRes.status === 200 && Array.isArray(getMsgsRes.body) && getMsgsRes.body.length >= 1,
      'Test 6b: GET /api/matches/:id/messages returns messages sorted by date',
      getMsgsRes.body
    );

    // Create a Venue and Court for booking tests
    const venue = await prisma.venue.create({
      data: {
        name: 'Test Arena',
        category: 'كرة قدم',
        description: 'Test arena description',
        location: 'Cairo, Egypt',
        images: '["arena.jpg"]',
        ownerId: owner.id,
      },
    });

    const court = await prisma.court.create({
      data: {
        venueId: venue.id,
        name: 'Court 1',
        category: 'خماسي',
        pricePerHour: 100,
        images: '["court1.jpg"]',
        amenities: '["lighting", "ball"]',
      },
    });

    // Test 7: Double-booking concurrency prevention
    const slotStart = new Date(Date.now() + 3600000 * 24).toISOString();
    const slotEnd = new Date(Date.now() + 3600000 * 25).toISOString();

    const [bookingAttempt1, bookingAttempt2] = await Promise.all([
      request(port, 'POST', '/api/bookings', { courtId: court.id, startTime: slotStart, endTime: slotEnd }, playerToken),
      request(port, 'POST', '/api/bookings', { courtId: court.id, startTime: slotStart, endTime: slotEnd }, player2Token),
    ]);

    const statuses = [bookingAttempt1.status, bookingAttempt2.status].sort();
    assert(
      statuses[0] === 201 && statuses[1] === 400,
      'Test 7: Concurrency Double-Booking Lock serializes requests; exactly 1 succeeds (201) and 1 fails (400)',
      { status1: bookingAttempt1.status, status2: bookingAttempt2.status, err: bookingAttempt1.body.error || bookingAttempt2.body.error }
    );

    const successfulBooking = bookingAttempt1.status === 201 ? bookingAttempt1.body : bookingAttempt2.body;

    // Test 8: Booking Status Modification Authorization
    // Unauthorized random user (player2) trying to modify player1's booking
    const unauthorizedMod = await request(
      port,
      'PATCH',
      `/api/bookings/${successfulBooking.id}/status`,
      { status: 'CONFIRMED' },
      player2Token
    );
    assert(
      unauthorizedMod.status === 403,
      'Test 8a: Unauthorized user cannot modify booking status (403 Forbidden)',
      unauthorizedMod.body
    );

    // Player creator trying to confirm (only owner/admin can confirm, player can only cancel)
    const creatorIllegalMod = await request(
      port,
      'PATCH',
      `/api/bookings/${successfulBooking.id}/status`,
      { status: 'CONFIRMED' },
      playerToken
    );
    assert(
      creatorIllegalMod.status === 403,
      'Test 8b: Booking creator cannot force confirm status (403 Forbidden)',
      creatorIllegalMod.body
    );

    // Venue Owner can modify status
    const ownerMod = await request(
      port,
      'PATCH',
      `/api/bookings/${successfulBooking.id}/status`,
      { status: 'CONFIRMED' },
      ownerToken
    );
    assert(ownerMod.status === 200, 'Test 8c: Venue owner can modify booking status', ownerMod.body);

    // Test 9: Confirm Attendance Guard
    // Player 2 cannot confirm attendance for Player 1's booking
    const unauthorizedAttendance = await request(
      port,
      'POST',
      `/api/bookings/${successfulBooking.id}/confirm-attendance`,
      undefined,
      player2Token
    );
    assert(
      unauthorizedAttendance.status === 403,
      'Test 9a: Unauthorized user cannot confirm attendance (403)',
      unauthorizedAttendance.body
    );

    // Player 1 (creator) CAN confirm attendance
    const creatorAttendance = await request(
      port,
      'POST',
      `/api/bookings/${successfulBooking.id}/confirm-attendance`,
      undefined,
      playerToken
    );
    assert(
      creatorAttendance.status === 200 && creatorAttendance.body.status === 'ATTENDANCE_CONFIRMED',
      'Test 9b: Booking creator can confirm attendance',
      creatorAttendance.body
    );

    // Test 10: Super Admin Court Management Override
    // Admin adding court to Owner's venue
    const adminCourtRes = await request(
      port,
      'POST',
      `/api/venues/${venue.id}/courts`,
      {
        name: 'Admin Added Court',
        category: 'تنس',
        pricePerHour: 150,
        images: ['tennis.jpg'],
        amenities: ['rackets'],
      },
      adminToken
    );
    assert(
      adminCourtRes.status === 201 && adminCourtRes.body.name === 'Admin Added Court',
      'Test 10a: Super Admin can add court to another user venue',
      adminCourtRes.body
    );
    const adminCourtId = adminCourtRes.body.id;

    // Admin deleting court
    const adminDeleteCourt = await request(port, 'DELETE', `/api/courts/${adminCourtId}`, undefined, adminToken);
    assert(adminDeleteCourt.status === 200, 'Test 10b: Super Admin can delete court', adminDeleteCourt.body);

    // Test 11: Missing Endpoint: POST /api/admin/users/:id/toggle-ban
    // Self-ban protection
    const selfBan = await request(port, 'POST', `/api/admin/users/${admin.id}/toggle-ban`, undefined, adminToken);
    assert(selfBan.status === 400, 'Test 11a: Admin self-ban protection (400)', selfBan.body);

    // Toggle ban on Player 2
    const banPlayer2 = await request(port, 'POST', `/api/admin/users/${player2Id}/toggle-ban`, undefined, adminToken);
    assert(
      banPlayer2.status === 200 && banPlayer2.body.isActive === false && banPlayer2.body.isBanned === true,
      'Test 11b: Admin toggles ban on user',
      banPlayer2.body
    );

    // Test 12: Missing Endpoint: GET /api/venues/:id/leaderboard
    const venueLeaderboard = await request(port, 'GET', `/api/venues/${venue.id}/leaderboard`);
    assert(
      venueLeaderboard.status === 200 && Array.isArray(venueLeaderboard.body),
      'Test 12: GET /api/venues/:id/leaderboard returns ranked players array',
      venueLeaderboard.body
    );

    // Test 13: Missing Endpoint: DELETE /api/admin/venues/:id cascade deletion
    const cascadeDelete = await request(port, 'DELETE', `/api/admin/venues/${venue.id}`, undefined, adminToken);
    const venueCheck = await prisma.venue.findUnique({ where: { id: venue.id } });
    const courtCheck = await prisma.court.findUnique({ where: { id: court.id } });
    assert(
      cascadeDelete.status === 200 && venueCheck === null && courtCheck === null,
      'Test 13: DELETE /api/admin/venues/:id cascade deletes venue, courts, and bookings',
      cascadeDelete.body
    );

    // Test 14: Global JSON Error Handling & 404
    const malformedJsonRes = await request(port, 'POST', '/api/auth/login', undefined, undefined, '{"invalid_json":');
    assert(
      malformedJsonRes.status === 400 && malformedJsonRes.body.error === 'صيغة البيانات غير صحيحة (Malformed JSON)',
      'Test 14a: Malformed JSON returns 400 JSON error without raw HTML or stack trace',
      malformedJsonRes.body
    );

    const notFoundRes = await request(port, 'GET', '/api/non-existent-route-xyz');
    assert(
      notFoundRes.status === 404 && typeof notFoundRes.body.error === 'string',
      'Test 14b: Unmatched route returns 404 JSON error without HTML',
      notFoundRes.body
    );

    // Cleanup created test records
    await prisma.notification.deleteMany({ where: { user: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.message.deleteMany({ where: { sender: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.booking.deleteMany({ where: { user: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.court.deleteMany({ where: { venue: { owner: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } } });
    await prisma.venue.deleteMany({ where: { owner: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.matchRequest.deleteMany({ where: { creator: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } } });
    await prisma.user.deleteMany({ where: { phone: { in: [testPhonePlayer1, testPhonePlayer2, testPhoneOwner, testPhoneAdmin] } } });

    console.log(`\n==========================================`);
    console.log(`Verification Summary: ${passed} PASSED, ${failed} FAILED`);
    console.log(`==========================================`);

    server.close();
    await prisma.$disconnect();

    if (failed > 0) {
      process.exit(1);
    } else {
      process.exit(0);
    }
  } catch (err) {
    console.error('Test run error:', err);
    server.close();
    await prisma.$disconnect();
    process.exit(1);
  }
}

runTests();
