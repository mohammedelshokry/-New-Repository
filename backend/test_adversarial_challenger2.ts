import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import http from 'http';

const PORT = 3088;
process.env.PORT = String(PORT);

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

async function runAdversarialSuite() {
  console.log('======================================================================');
  console.log('--- Challenger 2: Adversarial Verification & Contract Parity Suite ---');
  console.log(`--- Launching latest backend on 127.0.0.1:${PORT} ---`);
  console.log('======================================================================\n');

  // Import app after setting process.env.PORT
  // src/index.ts unconditionally starts app.listen(PORT, '0.0.0.0')
  await import('./src/index');
  await new Promise((r) => setTimeout(r, 1000));

  let passed = 0;
  let failed = 0;
  const failureDetails: string[] = [];

  function assert(condition: boolean, testName: string, detail?: any) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName}`);
      if (detail !== undefined) {
        console.error('       Details:', typeof detail === 'object' ? JSON.stringify(detail) : detail);
      }
      failureDetails.push(`${testName}: ${JSON.stringify(detail)}`);
      failed++;
    }
  }

  // Unique phone numbers for Challenger 2 testing
  const cPlayerPhone1 = '01200000001';
  const cPlayerPhone2 = '01200000002';
  const cOwnerPhone = '01200000003';
  const cAdminPhone = '01200000004';
  const testPhones = [cPlayerPhone1, cPlayerPhone2, cOwnerPhone, cAdminPhone];

  async function cleanupTestData() {
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
          const courts = await prisma.court.findMany({ where: { venueId: { in: venueIds } }, select: { id: true } });
          const courtIds = courts.map((c) => c.id);
          if (courtIds.length > 0) {
            await prisma.booking.deleteMany({ where: { courtId: { in: courtIds } } });
            await prisma.court.deleteMany({ where: { id: { in: courtIds } } });
          }
          await prisma.review.deleteMany({ where: { venueId: { in: venueIds } } });
          await prisma.venue.deleteMany({ where: { id: { in: venueIds } } });
        }

        await prisma.user.deleteMany({ where: { id: { in: userIds } } });
      }
    } catch (e) {
      console.warn('[Cleanup Warning]', e);
    }
  }

  try {
    await cleanupTestData();

    // Setup Test Users
    const pwdHash = await bcrypt.hash('AdvPass123!', 10);

    const player1 = await prisma.user.create({
      data: { name: 'Adv Player 1', phone: cPlayerPhone1, passwordHash: pwdHash, role: 'PLAYER', points: 200, level: 'BRONZE' },
    });
    const player1Token = jwt.sign({ userId: player1.id, role: player1.role }, JWT_SECRET);

    const player2 = await prisma.user.create({
      data: { name: 'Adv Player 2', phone: cPlayerPhone2, passwordHash: pwdHash, role: 'PLAYER', points: 600, level: 'SILVER' },
    });
    const player2Token = jwt.sign({ userId: player2.id, role: player2.role }, JWT_SECRET);

    const owner = await prisma.user.create({
      data: { name: 'Adv Venue Owner', phone: cOwnerPhone, passwordHash: pwdHash, role: 'OWNER' },
    });
    const ownerToken = jwt.sign({ userId: owner.id, role: owner.role }, JWT_SECRET);

    const admin = await prisma.user.create({
      data: { name: 'Adv Super Admin', phone: cAdminPhone, passwordHash: pwdHash, role: 'ADMIN' },
    });
    const adminToken = jwt.sign({ userId: admin.id, role: admin.role }, JWT_SECRET);

    // =================================================================
    // SECTION 1: PATCH /api/notifications/read-all
    // =================================================================
    console.log('\n--- Testing PATCH /api/notifications/read-all ---');

    // Adv 1: Unauthenticated
    const notifUnauth = await request(PORT, 'PATCH', '/api/notifications/read-all');
    assert(
      notifUnauth.status === 401 && notifUnauth.body.error === 'Unauthorized',
      'Adv 1: PATCH /api/notifications/read-all unauthenticated returns 401 { error: "Unauthorized" }',
      notifUnauth.body
    );

    // Adv 2: Invalid token
    const notifBadToken = await request(PORT, 'PATCH', '/api/notifications/read-all', undefined, 'invalid-jwt-token');
    assert(
      notifBadToken.status === 401 && notifBadToken.body.error === 'Invalid token',
      'Adv 2: PATCH /api/notifications/read-all invalid token returns 401 { error: "Invalid token" }',
      notifBadToken.body
    );

    // Adv 3: Zero notifications
    const notifZero = await request(PORT, 'PATCH', '/api/notifications/read-all', undefined, player1Token);
    assert(
      notifZero.status === 200 && notifZero.body.success === true && notifZero.body.count === 0,
      'Adv 3: PATCH /api/notifications/read-all with 0 notifications returns 200 { success: true, count: 0 }',
      notifZero.body
    );

    // Adv 4: Multiple notifications (3 unread, 2 already read)
    await prisma.notification.createMany({
      data: [
        { userId: player1.id, title: 'Unread 1', body: 'B1', type: 'TEST', isRead: false },
        { userId: player1.id, title: 'Unread 2', body: 'B2', type: 'TEST', isRead: false },
        { userId: player1.id, title: 'Unread 3', body: 'B3', type: 'TEST', isRead: false },
        { userId: player1.id, title: 'Read 1', body: 'B4', type: 'TEST', isRead: true },
        { userId: player1.id, title: 'Read 2', body: 'B5', type: 'TEST', isRead: true },
      ],
    });
    const notifBatch = await request(PORT, 'PATCH', '/api/notifications/read-all', undefined, player1Token);
    const unreadCountAfter = await prisma.notification.count({ where: { userId: player1.id, isRead: false } });
    const totalCountAfter = await prisma.notification.count({ where: { userId: player1.id } });
    assert(
      notifBatch.status === 200 &&
        notifBatch.body.success === true &&
        notifBatch.body.count === 3 &&
        unreadCountAfter === 0 &&
        totalCountAfter === 5,
      'Adv 4: PATCH /api/notifications/read-all marks only unread notifications as read and updates count correctly',
      { resp: notifBatch.body, unreadCountAfter, totalCountAfter }
    );

    // Adv 5: Extraneous body payload ignored gracefully
    const notifExtraBody = await request(PORT, 'PATCH', '/api/notifications/read-all', { dummy: 123 }, player1Token);
    assert(
      notifExtraBody.status === 200 && notifExtraBody.body.success === true,
      'Adv 5: PATCH /api/notifications/read-all handles unexpected body without failing',
      notifExtraBody.body
    );

    // =================================================================
    // SECTION 2: GET & POST /api/matches/:id/messages
    // =================================================================
    console.log('\n--- Testing GET & POST /api/matches/:id/messages ---');

    // Create a valid match request
    const match = await prisma.matchRequest.create({
      data: {
        creatorId: player1.id,
        title: 'Adv Match Game',
        description: 'Testing chat messages',
        matchTime: new Date(Date.now() + 86400000),
        missingSpots: 3,
        costPerSpot: 40,
        status: 'OPEN',
      },
    });

    // Adv 6: GET messages with non-existent match ID
    const getMsgNonExistent = await request(PORT, 'GET', '/api/matches/non-existent-match-id-12345/messages', undefined, player1Token);
    assert(
      getMsgNonExistent.status === 404 && getMsgNonExistent.body.error === 'Match request not found',
      'Adv 6: GET /api/matches/:id/messages with non-existent ID returns 404 { error: "Match request not found" }',
      getMsgNonExistent.body
    );

    // Adv 7: POST message with non-existent match ID
    const postMsgNonExistent = await request(
      PORT,
      'POST',
      '/api/matches/non-existent-match-id-12345/messages',
      { content: 'Hello' },
      player1Token
    );
    assert(
      postMsgNonExistent.status === 404 && postMsgNonExistent.body.error === 'Match request not found',
      'Adv 7: POST /api/matches/:id/messages with non-existent ID returns 404 { error: "Match request not found" }',
      postMsgNonExistent.body
    );

    // Adv 8: POST message with empty body
    const postMsgEmptyBody = await request(PORT, 'POST', `/api/matches/${match.id}/messages`, {}, player1Token);
    assert(
      postMsgEmptyBody.status === 400 && postMsgEmptyBody.body.error === 'Message content cannot be empty',
      'Adv 8: POST /api/matches/:id/messages with empty body returns 400 { error: "Message content cannot be empty" }',
      postMsgEmptyBody.body
    );

    // Adv 9: POST message with empty string
    const postMsgEmptyString = await request(PORT, 'POST', `/api/matches/${match.id}/messages`, { content: '' }, player1Token);
    assert(
      postMsgEmptyString.status === 400 && postMsgEmptyString.body.error === 'Message content cannot be empty',
      'Adv 9: POST /api/matches/:id/messages with empty string returns 400',
      postMsgEmptyString.body
    );

    // Adv 10: POST message with whitespace only
    const postMsgWhitespace = await request(PORT, 'POST', `/api/matches/${match.id}/messages`, { content: '   \n\t   ' }, player1Token);
    assert(
      postMsgWhitespace.status === 400 && postMsgWhitespace.body.error === 'Message content cannot be empty',
      'Adv 10: POST /api/matches/:id/messages with whitespace-only content returns 400',
      postMsgWhitespace.body
    );

    // Adv 11: POST message with non-string content
    const postMsgNonString = await request(PORT, 'POST', `/api/matches/${match.id}/messages`, { content: 12345 }, player1Token);
    assert(
      postMsgNonString.status === 400 && postMsgNonString.body.error === 'Message content cannot be empty',
      'Adv 11: POST /api/matches/:id/messages with numeric content returns 400',
      postMsgNonString.body
    );

    // Adv 12: GET messages on match with 0 messages
    const getMsgEmpty = await request(PORT, 'GET', `/api/matches/${match.id}/messages`, undefined, player1Token);
    assert(
      getMsgEmpty.status === 200 && Array.isArray(getMsgEmpty.body) && getMsgEmpty.body.length === 0,
      'Adv 12: GET /api/matches/:id/messages with 0 messages returns 200 []',
      getMsgEmpty.body
    );

    // Adv 13: POST valid message with untrimmed content
    const postMsgValid1 = await request(
      PORT,
      'POST',
      `/api/matches/${match.id}/messages`,
      { content: '   أنا جاهز للاشتراك في المباراة   ' },
      player1Token
    );
    assert(
      postMsgValid1.status === 201 &&
        postMsgValid1.body.content === 'أنا جاهز للاشتراك في المباراة' &&
        postMsgValid1.body.senderId === player1.id &&
        postMsgValid1.body.sender &&
        postMsgValid1.body.sender.id === player1.id &&
        postMsgValid1.body.sender.avatarUrl !== undefined &&
        postMsgValid1.body.sender.profilePic !== undefined,
      'Adv 13: POST /api/matches/:id/messages trims content, secures senderId, returns avatarUrl & profilePic',
      postMsgValid1.body
    );

    // Post second message from player 2
    await new Promise((r) => setTimeout(r, 50));
    const postMsgValid2 = await request(
      PORT,
      'POST',
      `/api/matches/${match.id}/messages`,
      { content: 'وأنا أيضاً جاهز!' },
      player2Token
    );
    assert(
      postMsgValid2.status === 201 && postMsgValid2.body.senderId === player2.id,
      'Adv 14a: POST /api/matches/:id/messages second message from Player 2 succeeds',
      postMsgValid2.body
    );

    // Adv 14: GET messages sorted chronologically ascending
    const getMsgChronological = await request(PORT, 'GET', `/api/matches/${match.id}/messages`, undefined, player1Token);
    const msgs = getMsgChronological.body;
    const isSortedAsc =
      Array.isArray(msgs) &&
      msgs.length === 2 &&
      new Date(msgs[0].createdAt).getTime() <= new Date(msgs[1].createdAt).getTime() &&
      msgs[0].content === 'أنا جاهز للاشتراك في المباراة' &&
      msgs[1].content === 'وأنا أيضاً جاهز!';
    assert(
      getMsgChronological.status === 200 && isSortedAsc,
      'Adv 14b: GET /api/matches/:id/messages returns messages in ASCENDING chronological order',
      msgs
    );

    // Adv 15: Unauthenticated GET & POST
    const msgUnauthGet = await request(PORT, 'GET', `/api/matches/${match.id}/messages`);
    const msgUnauthPost = await request(PORT, 'POST', `/api/matches/${match.id}/messages`, { content: 'test' });
    assert(
      msgUnauthGet.status === 401 && msgUnauthGet.body.error === 'Unauthorized' &&
      msgUnauthPost.status === 401 && msgUnauthPost.body.error === 'Unauthorized',
      'Adv 15: Chat messages endpoints strictly require authentication (401)',
      { get: msgUnauthGet.body, post: msgUnauthPost.body }
    );

    // =================================================================
    // SECTION 3: POST /api/admin/users/:id/toggle-ban
    // =================================================================
    console.log('\n--- Testing POST /api/admin/users/:id/toggle-ban ---');

    // Adv 16: Unauthenticated
    const banUnauth = await request(PORT, 'POST', `/api/admin/users/${player2.id}/toggle-ban`);
    assert(
      banUnauth.status === 401 && banUnauth.body.error === 'Unauthorized',
      'Adv 16: POST /api/admin/users/:id/toggle-ban unauthenticated returns 401 { error: "Unauthorized" }',
      banUnauth.body
    );

    // Adv 17: Caller with role PLAYER
    const banByPlayer = await request(PORT, 'POST', `/api/admin/users/${player2.id}/toggle-ban`, undefined, player1Token);
    assert(
      banByPlayer.status === 403 && banByPlayer.body.error === 'Forbidden',
      'Adv 17: POST /api/admin/users/:id/toggle-ban by PLAYER returns 403 { error: "Forbidden" }',
      banByPlayer.body
    );

    // Adv 18: Caller with role OWNER
    const banByOwner = await request(PORT, 'POST', `/api/admin/users/${player2.id}/toggle-ban`, undefined, ownerToken);
    assert(
      banByOwner.status === 403 && banByOwner.body.error === 'Forbidden',
      'Adv 18: POST /api/admin/users/:id/toggle-ban by OWNER returns 403 { error: "Forbidden" }',
      banByOwner.body
    );

    // Adv 19: Admin attempts self-ban
    const banSelf = await request(PORT, 'POST', `/api/admin/users/${admin.id}/toggle-ban`, undefined, adminToken);
    assert(
      banSelf.status === 400 && banSelf.body.error === 'Cannot ban your own account',
      'Adv 19: POST /api/admin/users/:id/toggle-ban prevents Admin self-ban (400)',
      banSelf.body
    );

    // Adv 20: Non-existent user
    const banNonExistent = await request(PORT, 'POST', '/api/admin/users/non-existent-user-uuid/toggle-ban', undefined, adminToken);
    assert(
      banNonExistent.status === 404 && banNonExistent.body.error === 'User not found',
      'Adv 20: POST /api/admin/users/:id/toggle-ban on non-existent user returns 404',
      banNonExistent.body
    );

    // Adv 21: Toggle ban to true (account suspended)
    const banExecute = await request(PORT, 'POST', `/api/admin/users/${player2.id}/toggle-ban`, undefined, adminToken);
    assert(
      banExecute.status === 200 &&
        banExecute.body.success === true &&
        banExecute.body.isActive === false &&
        banExecute.body.isBanned === true &&
        banExecute.body.user &&
        banExecute.body.user.passwordHash === undefined,
      'Adv 21: POST /api/admin/users/:id/toggle-ban deactivates user, returns isBanned: true without passwordHash',
      banExecute.body
    );

    // Adv 22: Suspended user cannot login
    const suspendedLogin = await request(PORT, 'POST', '/api/auth/login', { phone: cPlayerPhone2, password: 'AdvPass123!' });
    assert(
      suspendedLogin.status === 401 && suspendedLogin.body.error === 'Invalid credentials or account suspended',
      'Adv 22: Suspended/banned user is blocked from logging in with 401',
      suspendedLogin.body
    );

    // Adv 23: Toggle ban again (unban)
    const unbanExecute = await request(PORT, 'POST', `/api/admin/users/${player2.id}/toggle-ban`, undefined, adminToken);
    assert(
      unbanExecute.status === 200 &&
        unbanExecute.body.success === true &&
        unbanExecute.body.isActive === true &&
        unbanExecute.body.isBanned === false,
      'Adv 23: POST /api/admin/users/:id/toggle-ban unbans user (isActive: true, isBanned: false)',
      unbanExecute.body
    );

    // Adv 24: Unbanned user can log in again
    const restoredLogin = await request(PORT, 'POST', '/api/auth/login', { phone: cPlayerPhone2, password: 'AdvPass123!' });
    assert(
      restoredLogin.status === 200 && restoredLogin.body.token && restoredLogin.body.user.phone === cPlayerPhone2,
      'Adv 24: Unbanned user can successfully log in again',
      restoredLogin.body
    );

    // =================================================================
    // SECTION 4: DELETE /api/admin/venues/:id & DELETE /api/admin/pitches/:id
    // =================================================================
    console.log('\n--- Testing DELETE /api/admin/venues/:id & /api/admin/pitches/:id ---');

    // Create a standalone venue with no courts
    const emptyVenue = await prisma.venue.create({
      data: {
        name: 'Empty Adv Venue',
        category: 'بادل',
        description: 'Empty venue for deletion test',
        location: 'Cairo, Egypt',
        images: '[]',
        ownerId: owner.id,
      },
    });

    // Adv 25: Unauthenticated
    const delUnauth = await request(PORT, 'DELETE', `/api/admin/venues/${emptyVenue.id}`);
    assert(
      delUnauth.status === 401 && delUnauth.body.error === 'Unauthorized',
      'Adv 25: DELETE /api/admin/venues/:id unauthenticated returns 401',
      delUnauth.body
    );

    // Adv 26: Caller with role PLAYER
    const delPlayer = await request(PORT, 'DELETE', `/api/admin/venues/${emptyVenue.id}`, undefined, player1Token);
    assert(
      delPlayer.status === 403 && delPlayer.body.error === 'Forbidden',
      'Adv 26: DELETE /api/admin/venues/:id by PLAYER returns 403',
      delPlayer.body
    );

    // Adv 27: Caller with role OWNER (even venue owner cannot call admin endpoint)
    const delOwner = await request(PORT, 'DELETE', `/api/admin/venues/${emptyVenue.id}`, undefined, ownerToken);
    assert(
      delOwner.status === 403 && delOwner.body.error === 'Forbidden',
      'Adv 27: DELETE /api/admin/venues/:id by OWNER returns 403',
      delOwner.body
    );

    // Adv 28: Non-existent venue via /api/admin/venues/:id
    const delNonExistentVenue = await request(PORT, 'DELETE', '/api/admin/venues/non-existent-venue-xyz', undefined, adminToken);
    assert(
      delNonExistentVenue.status === 404 && delNonExistentVenue.body.error === 'Venue not found',
      'Adv 28: DELETE /api/admin/venues/:id on non-existent venue returns 404 { error: "Venue not found" }',
      delNonExistentVenue.body
    );

    // Adv 29: Non-existent venue via /api/admin/pitches/:id
    const delNonExistentPitch = await request(PORT, 'DELETE', '/api/admin/pitches/non-existent-pitch-xyz', undefined, adminToken);
    assert(
      delNonExistentPitch.status === 404 && delNonExistentPitch.body.error === 'Venue not found',
      'Adv 29: DELETE /api/admin/pitches/:id on non-existent venue returns 404 { error: "Venue not found" }',
      delNonExistentPitch.body
    );

    // Adv 30: Delete empty venue via /api/admin/venues/:id
    const delEmptyVenueRes = await request(PORT, 'DELETE', `/api/admin/venues/${emptyVenue.id}`, undefined, adminToken);
    const emptyVenueDbCheck = await prisma.venue.findUnique({ where: { id: emptyVenue.id } });
    assert(
      delEmptyVenueRes.status === 200 && delEmptyVenueRes.body.success === true && emptyVenueDbCheck === null,
      'Adv 30: DELETE /api/admin/venues/:id successfully deletes empty venue without foreign key issues',
      delEmptyVenueRes.body
    );

    // Create a complex venue with courts, bookings, reviews for cascade test via /api/admin/pitches/:id
    const complexVenue = await prisma.venue.create({
      data: {
        name: 'Complex Cascade Venue',
        category: 'كرة قدم',
        description: 'Venue with full hierarchy',
        location: 'Alexandria, Egypt',
        images: '["v1.jpg"]',
        ownerId: owner.id,
      },
    });

    const courtA = await prisma.court.create({
      data: {
        venueId: complexVenue.id,
        name: 'Court Alpha',
        category: 'خماسي',
        pricePerHour: 120,
        images: '[]',
        amenities: '[]',
      },
    });

    const courtB = await prisma.court.create({
      data: {
        venueId: complexVenue.id,
        name: 'Court Beta',
        category: 'سباعي',
        pricePerHour: 180,
        images: '[]',
        amenities: '[]',
      },
    });

    const booking1 = await prisma.booking.create({
      data: {
        courtId: courtA.id,
        userId: player1.id,
        startTime: new Date(Date.now() + 1000000),
        endTime: new Date(Date.now() + 2000000),
        price: 120,
        platformFee: 6,
        ownerAmount: 114,
        status: 'CONFIRMED',
      },
    });

    const review1 = await prisma.review.create({
      data: {
        venueId: complexVenue.id,
        userId: player1.id,
        rating: 5,
        comment: 'Great stadium!',
      },
    });

    // Adv 31: Delete complex venue via /api/admin/pitches/:id (Cascade test)
    const delPitchesCascade = await request(PORT, 'DELETE', `/api/admin/pitches/${complexVenue.id}`, undefined, adminToken);
    const venueCheck = await prisma.venue.findUnique({ where: { id: complexVenue.id } });
    const courtACheck = await prisma.court.findUnique({ where: { id: courtA.id } });
    const courtBCheck = await prisma.court.findUnique({ where: { id: courtB.id } });
    const bookingCheck = await prisma.booking.findUnique({ where: { id: booking1.id } });
    const reviewCheck = await prisma.review.findUnique({ where: { id: review1.id } });

    assert(
      delPitchesCascade.status === 200 &&
        delPitchesCascade.body.success === true &&
        venueCheck === null &&
        courtACheck === null &&
        courtBCheck === null &&
        bookingCheck === null &&
        reviewCheck === null,
      'Adv 31: DELETE /api/admin/pitches/:id atomically cascades and removes courts, bookings, reviews, and venue',
      delPitchesCascade.body
    );

    // =================================================================
    // SECTION 5: GET /api/venues/:id/leaderboard
    // =================================================================
    console.log('\n--- Testing GET /api/venues/:id/leaderboard ---');

    // Adv 32: Non-existent venue ID
    const leadNonExistent = await request(PORT, 'GET', '/api/venues/non-existent-venue-xyz/leaderboard');
    assert(
      leadNonExistent.status === 404 && leadNonExistent.body.error === 'Venue not found',
      'Adv 32: GET /api/venues/:id/leaderboard on non-existent venue returns 404 { error: "Venue not found" }',
      leadNonExistent.body
    );

    // Create a fresh venue for leaderboard testing
    const lbVenue = await prisma.venue.create({
      data: {
        name: 'Leaderboard Arena',
        category: 'كرة مضرب',
        description: 'For testing leaderboard rankings',
        location: 'Giza, Egypt',
        images: '[]',
        ownerId: owner.id,
      },
    });

    const lbCourt = await prisma.court.create({
      data: {
        venueId: lbVenue.id,
        name: 'LB Court 1',
        category: 'تنس',
        pricePerHour: 90,
        images: '[]',
        amenities: '[]',
      },
    });

    // Adv 33: Venue with 0 bookings
    const lbEmpty = await request(PORT, 'GET', `/api/venues/${lbVenue.id}/leaderboard`);
    assert(
      lbEmpty.status === 200 && Array.isArray(lbEmpty.body) && lbEmpty.body.length === 0,
      'Adv 33: GET /api/venues/:id/leaderboard on venue with 0 bookings returns 200 []',
      lbEmpty.body
    );

    // Adv 34: Venue with only CANCELLED and REJECTED bookings
    await prisma.booking.createMany({
      data: [
        {
          courtId: lbCourt.id,
          userId: player1.id,
          startTime: new Date(Date.now() + 5000000),
          endTime: new Date(Date.now() + 6000000),
          price: 90,
          platformFee: 4.5,
          ownerAmount: 85.5,
          status: 'CANCELLED',
        },
        {
          courtId: lbCourt.id,
          userId: player2.id,
          startTime: new Date(Date.now() + 7000000),
          endTime: new Date(Date.now() + 8000000),
          price: 90,
          platformFee: 4.5,
          ownerAmount: 85.5,
          status: 'REJECTED',
        },
      ],
    });
    const lbCancelledOnly = await request(PORT, 'GET', `/api/venues/${lbVenue.id}/leaderboard`);
    assert(
      lbCancelledOnly.status === 200 && Array.isArray(lbCancelledOnly.body) && lbCancelledOnly.body.length === 0,
      'Adv 34: GET /api/venues/:id/leaderboard strictly filters out CANCELLED and REJECTED bookings',
      lbCancelledOnly.body
    );

    // Adv 35: Active bookings with rank sorting
    // Player 1 has 200 points, Player 2 has 600 points
    // Let's create CONFIRMED booking for Player 1, and ATTENDANCE_CONFIRMED for Player 2
    await prisma.booking.createMany({
      data: [
        {
          courtId: lbCourt.id,
          userId: player1.id,
          startTime: new Date(Date.now() + 9000000),
          endTime: new Date(Date.now() + 10000000),
          price: 90,
          platformFee: 4.5,
          ownerAmount: 85.5,
          status: 'CONFIRMED',
        },
        {
          courtId: lbCourt.id,
          userId: player2.id,
          startTime: new Date(Date.now() + 11000000),
          endTime: new Date(Date.now() + 12000000),
          price: 90,
          platformFee: 4.5,
          ownerAmount: 85.5,
          status: 'ATTENDANCE_CONFIRMED',
        },
      ],
    });

    const lbRanked = await request(PORT, 'GET', `/api/venues/${lbVenue.id}/leaderboard`);
    const leaderboard = lbRanked.body;
    const isPlayer2First =
      Array.isArray(leaderboard) &&
      leaderboard.length === 2 &&
      leaderboard[0].id === player2.id &&
      leaderboard[0].points === 600 &&
      leaderboard[1].id === player1.id &&
      leaderboard[1].points === 200 &&
      leaderboard[0].venueBookingsCount === 1;

    assert(
      lbRanked.status === 200 && isPlayer2First,
      'Adv 35: GET /api/venues/:id/leaderboard correctly aggregates and ranks players by points DESC',
      leaderboard
    );

    // =================================================================
    // SECTION 6: Edge Cases & JSON Error Format Parity
    // =================================================================
    console.log('\n--- Testing Edge Cases & Error Format Robustness ---');

    // Adv 36: Malformed JSON body
    const malformed = await request(PORT, 'POST', '/api/auth/login', undefined, undefined, '{"bad_json:');
    assert(
      malformed.status === 400 && malformed.body.error === 'صيغة البيانات غير صحيحة (Malformed JSON)',
      'Adv 36: Malformed JSON payload returns 400 with clean Arabic error message and no HTML',
      malformed.body
    );

    // Adv 37: 404 Route Fallback
    const route404 = await request(PORT, 'GET', '/api/some/non-existent/sub-route');
    assert(
      route404.status === 404 && typeof route404.body.error === 'string',
      'Adv 37: 404 Fallback returns structured JSON { error: string } without HTML',
      route404.body
    );

    // Adv 38: GET non-existent court
    const court404 = await request(PORT, 'GET', '/api/courts/non-existent-court-uuid-xyz');
    assert(
      court404.status === 404 && court404.body.error === 'Court not found',
      'Adv 38: GET /api/courts/:id on non-existent court returns 404 { error: "Court not found" }',
      court404.body
    );

    // Adv 39: POST /api/bookings with invalid date strings
    const bookingBadDates = await request(
      PORT,
      'POST',
      '/api/bookings',
      { courtId: lbCourt.id, startTime: 'not-a-date', endTime: 'invalid-date' },
      player1Token
    );
    assert(
      bookingBadDates.status === 400 && bookingBadDates.body.error === 'صيغة تاريخ الحجز غير صحيحة',
      'Adv 39: POST /api/bookings with invalid date string returns 400 { error: "صيغة تاريخ الحجز غير صحيحة" }',
      bookingBadDates.body
    );

    // Adv 40: POST /api/bookings with startTime >= endTime
    const now = Date.now();
    const bookingInvertedTimes = await request(
      PORT,
      'POST',
      '/api/bookings',
      {
        courtId: lbCourt.id,
        startTime: new Date(now + 7200000).toISOString(),
        endTime: new Date(now + 3600000).toISOString(),
      },
      player1Token
    );
    assert(
      bookingInvertedTimes.status === 400 && bookingInvertedTimes.body.error === 'وقت بداية الحجز يجب أن يكون قبل وقت النهاية',
      'Adv 40: POST /api/bookings with startTime >= endTime returns 400',
      bookingInvertedTimes.body
    );

    // Adv 41: POST /api/bookings missing courtId
    const bookingMissingFields = await request(
      PORT,
      'POST',
      '/api/bookings',
      { startTime: new Date(now + 3600000).toISOString(), endTime: new Date(now + 7200000).toISOString() },
      player1Token
    );
    assert(
      bookingMissingFields.status === 400 &&
        bookingMissingFields.body.error === 'بيانات الحجز غير مكتملة (courtId, startTime, endTime مطلوبة)',
      'Adv 41: POST /api/bookings with missing required fields returns 400',
      bookingMissingFields.body
    );

    // Adv 42: PATCH /api/bookings/:id/status on non-existent booking
    const patchStatus404 = await request(
      PORT,
      'PATCH',
      '/api/bookings/non-existent-booking-xyz/status',
      { status: 'CANCELLED' },
      player1Token
    );
    assert(
      patchStatus404.status === 404 && patchStatus404.body.error === 'Booking not found',
      'Adv 42: PATCH /api/bookings/:id/status on non-existent booking returns 404',
      patchStatus404.body
    );

    // Adv 43: POST /api/bookings/:id/confirm-attendance on non-existent booking
    const confirm404 = await request(
      PORT,
      'POST',
      '/api/bookings/non-existent-booking-xyz/confirm-attendance',
      undefined,
      player1Token
    );
    assert(
      confirm404.status === 404 && confirm404.body.error === 'Booking not found',
      'Adv 43: POST /api/bookings/:id/confirm-attendance on non-existent booking returns 404',
      confirm404.body
    );

    // Clean up created test data
    await cleanupTestData();

    console.log('\n======================================================================');
    console.log(`--- Adversarial Suite Summary: ${passed} PASSED, ${failed} FAILED ---`);
    console.log('======================================================================\n');

    await prisma.$disconnect();

    if (failed > 0) {
      console.error('Failure Log:', failureDetails);
      process.exit(1);
    } else {
      process.exit(0);
    }
  } catch (err) {
    console.error('[Adversarial Suite Execution Error]', err);
    await cleanupTestData();
    await prisma.$disconnect();
    process.exit(1);
  }
}

runAdversarialSuite();
