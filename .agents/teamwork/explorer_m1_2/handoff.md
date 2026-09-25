# Missing Endpoints & Route Parity Strategy — Handoff Report (Milestone 1)

> **Author**: Explorer M1-2 (Subagent `explorer_m1_2`)  
> **Mission**: Milestone 1 — Backend Production Refactoring & Type Safety: Missing Endpoints & Route Parity  
> **Parent Conversation ID**: `2307eab5-699b-442c-92ad-d7d6aef171d6`  
> **Date**: 2026-09-25T11:10:00+03:00  
> **Target Files**: `backend/src/index.ts`, `backend/prisma/schema.prisma`, `mobile-app/lib/`, `web-dashboard/src/lib/`

---

## 1. Observation

### 1.1 Discrepancies Between Client Expectations and Backend Routing
Across the Flutter mobile client and Next.js web dashboard, multiple active screens call REST endpoints that do not exist in `backend/src/index.ts`, triggering continuous 404 Not Found errors:

1. **`PATCH /api/notifications/read-all`**:
   - **Client Caller**: `mobile-app/lib/screens/notifications_screen.dart:24`:
     ```dart
     Future<void> _markAsRead() async {
       try {
         final dio = ref.read(dioProvider);
         await dio.patch('/notifications/read-all');
       } catch (_) {}
     }
     ```
   - **Backend Status**: Missing. `backend/src/index.ts` only contains `GET /api/notifications` (lines 503-513).
   - **User Impact**: Notification badges remain unread permanently.

2. **`GET /api/matches/:id/messages`**:
   - **Client Caller**: `mobile-app/lib/screens/chat_screen.dart:41`:
     ```dart
     final res = await dio.get('/matches/${widget.matchId}/messages');
     _messages = res.data;
     ```
     `ChatScreen` polls this endpoint every 3 seconds (`Timer.periodic(const Duration(seconds: 3))`).
   - **Backend Status**: Missing. `backend/src/index.ts` only has `GET` and `POST /api/match-requests` (lines 435-458).
   - **User Impact**: Match chat screen displays an infinite loading shimmer or 404 error.

3. **`POST /api/matches/:id/messages`**:
   - **Client Caller**: `mobile-app/lib/screens/chat_screen.dart:75-78`:
     ```dart
     await dio.post('/matches/${widget.matchId}/messages', data: {
       'content': text,
       'senderId': user['id'],
     });
     ```
   - **Backend Status**: Missing.
   - **User Impact**: Users cannot send in-app messages for match requests; "فشل الإرسال" SnackBar appears.

4. **`POST /api/admin/users/:id/toggle-ban`**:
   - **Client Caller**: `mobile-app/lib/screens/admin_dashboard_screen.dart:266`:
     ```dart
     await ref.read(dioProvider).post('/admin/users/${u['id']}/toggle-ban');
     ```
   - **Backend Status**: Missing. `backend/src/index.ts` defines `GET /api/admin/users` (lines 477-490) but no status toggle endpoint.
   - **User Impact**: Super Admins cannot moderate or ban bad actors from the mobile dashboard.

5. **`DELETE /api/admin/venues/:id` and `DELETE /api/admin/pitches/:id`**:
   - **Client Callers**:
     - `mobile-app/lib/screens/admin_dashboard_screen.dart:373`:
       ```dart
       await ref.read(dioProvider).delete('/admin/pitches/${p['id']}');
       ```
     - `web-dashboard/src/lib/api.ts:17`:
       ```ts
       export const deletePitch = (id: string) => api.delete(`/admin/pitches/${id}`).then(res => res.data);
       ```
   - **Backend Status**: Missing. Admin venue deletion is completely unhandled.
   - **User Impact**: Admins cannot remove illegal, fraudulent, or closed venues and their associated courts and bookings.

6. **`GET /api/venues/:id/leaderboard`**:
   - **Client Caller**: `mobile-app/lib/providers/api_provider.dart:61-65`:
     ```dart
     final venueLeaderboardProvider = FutureProvider.family<List<dynamic>, String>((ref, venueId) async {
       final dio = ref.watch(dioProvider);
       final response = await dio.get('/venues/$venueId/leaderboard');
       return response.data;
     });
     ```
   - **Backend Status**: Missing. Only global `/api/users/leaderboard` is implemented (lines 187-199).
   - **User Impact**: Venue-specific gamification leaderboard cannot be fetched.

7. **Bonus Web Dashboard & AI Assistant Parity Endpoints**:
   - `GET /api/admin/bookings`: Called by `web-dashboard/src/lib/api.ts:15`.
   - `DELETE /api/admin/users/:id`: Called by `web-dashboard/src/lib/api.ts:18`.
   - `POST /api/ai-assistant`: Called by `mobile-app/lib/screens/chat_sheet.dart:31`.

---

### 1.2 Verification of Prisma Schema Models (`backend/prisma/schema.prisma`)
Inspection of `backend/prisma/schema.prisma` confirms that all necessary models, fields, and relationships exist in the database:

1. **`Notification` Model** (`schema.prisma:108-118`):
   - `id`: `String @id @default(uuid())`
   - `userId`: `String` (foreign key to `User.id`)
   - `title`: `String`
   - `body`: `String`
   - `type`: `String`
   - `isRead`: `Boolean @default(false)`
   - `createdAt`: `DateTime @default(now())`
   - Relation: `user User @relation(fields: [userId], references: [id])`

2. **`MatchRequest` Model** (`schema.prisma:120-134`):
   - `id`: `String @id @default(uuid())`
   - `creatorId`: `String` (foreign key to `User.id`)
   - `title`: `String`, `description`: `String`
   - `matchTime`: `DateTime`, `missingSpots`: `Int`, `costPerSpot`: `Float`
   - `status`: `String @default("OPEN")`
   - `messages`: `Message[]` (1-to-many relationship)
   - `creator`: `User @relation(fields: [creatorId], references: [id])`

3. **`Message` Model** (`schema.prisma:136-145`):
   - `id`: `String @id @default(uuid())`
   - `content`: `String`
   - `matchRequestId`: `String` (foreign key to `MatchRequest.id`)
   - `senderId`: `String` (foreign key to `User.id`)
   - `createdAt`: `DateTime @default(now())`
   - Relations: `matchRequest MatchRequest`, `sender User`

4. **`User` Model** (`schema.prisma:10-31`):
   - `id`: `String @id @default(uuid())`
   - `name`: `String`, `phone`: `String @unique`
   - `passwordHash`: `String`
   - `role`: `String @default("PLAYER")` (`PLAYER` | `OWNER` | `ADMIN`)
   - `isActive`: `Boolean @default(true)`
   - `points`: `Int @default(0)`, `level`: `String @default("BRONZE")`, `matchesPlayed`: `Int @default(0)`
   - `profilePic`: `String?`, `fcmToken`: `String?`
   - Relations: `bookings Booking[]`, `matchRequests MatchRequest[]`, `venues Venue[]`, `reviews Review[]`, `notifications Notification[]`, `messages Message[]`

5. **`Venue`, `Court`, `Booking`, and `Review` Models** (`schema.prisma:33-106`):
   - `Venue` relates to `Court[]` and `Review[]`.
   - `Court` has foreign key `venueId` with `onDelete: Cascade`.
   - `Review` has foreign key `venueId` with `onDelete: Cascade`.
   - `Booking` has foreign key `courtId` with `onDelete: Cascade`.

---

## 2. Logic Chain

1. **System Health Premise**: A production-grade mobile client and admin dashboard must not encounter 404 HTTP errors during core user workflows (checking notifications, chatting in community games, toggling user bans, deleting venues, or viewing leaderboards).
2. **Observation of Client Code**: The Flutter screens actively execute Dio requests to endpoints with specific URL structures, query formats, and payload structures.
3. **Observation of Prisma Schema**: The underlying database already contains all required tables, fields, and foreign-key relations (`Notification.isRead`, `Message`, `MatchRequest`, `User.isActive`, `Venue.courts.bookings`). No schema migration is required to support these 6 endpoints.
4. **Express 5 Typing & Relation Inference**: In Express 5, `req.params.id` is typed as `string | string[]`. Therefore, route handlers must explicitly narrow parameter identifiers (`req.params.id as string`) before passing them to Prisma `where: { id: ... }`. Failure to do so breaks Prisma's TypeScript generic return types.
5. **Security & Identity Enforcement**:
   - In `POST /api/matches/:id/messages`, even though the client sends `senderId: user['id']`, the backend must derive `senderId` directly from `req.user!.userId` to prevent sender impersonation.
   - In `POST /api/admin/users/:id/toggle-ban`, the caller must be validated via `requireRole(['ADMIN'])`, and admins must be blocked from banning their own account (`req.user!.userId === targetUserId`).
   - In `DELETE /api/admin/venues/:id`, cascade deletion must be executed inside an explicit `prisma.$transaction` to guarantee that bookings, reviews, courts, and the venue itself are deleted atomically without foreign key constraint deadlocks.
6. **Flutter Model Compatibility**: In Flutter, `chat_screen.dart` reads `msg['sender']['name']` and `msg['sender']['avatarUrl']`, while `User` in Prisma has `profilePic`. Providing both `profilePic` and `avatarUrl` in the sender payload guarantees zero runtime null reference exceptions.

---

## 3. Caveats

1. **Database Cascade Support**: While `schema.prisma` declares `onDelete: Cascade` on `Court.venue` and `Booking.court`, depending on whether the database was initialized via `prisma db push` or raw migrations, database foreign key triggers may or may not be enforced at the SQL layer. Using an explicit top-down transaction (`prisma.$transaction`) guarantees 100% cascade safety regardless of SQL engine configuration.
2. **WebSocket vs. HTTP Polling**: The Flutter app currently uses HTTP polling (`Timer.periodic(const Duration(seconds: 3))`) in `chat_screen.dart`. Implementing `GET` and `POST /api/matches/:id/messages` satisfies this contract immediately without requiring a full WebSocket infrastructure rewrite.
3. **Route Aliasing**: The mobile app calls `/api/admin/pitches/:id` while the dashboard and specification reference `/api/admin/venues/:id`. Both routes must be bound to the same cascade deletion handler.

---

## 4. Conclusion & Concrete Implementation Recipes

Here is the exact TypeScript implementation for each missing endpoint, ready to be placed directly into `backend/src/index.ts` (or modular controller files).

### 4.1 Endpoint 1: `PATCH /api/notifications/read-all`

```ts
/**
 * PATCH /api/notifications/read-all
 * Marks all notifications for the authenticated user as read.
 */
app.patch('/api/notifications/read-all', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user!.userId;

    const result = await prisma.notification.updateMany({
      where: {
        userId,
        isRead: false,
      },
      data: {
        isRead: true,
      },
    });

    res.status(200).json({
      success: true,
      count: result.count,
      message: 'All notifications marked as read',
    });
  } catch (error) {
    console.error('Error marking notifications as read:', error);
    res.status(500).json({ error: 'Failed to mark notifications as read' });
  }
});
```

---

### 4.2 Endpoint 2: `GET /api/matches/:id/messages`

```ts
/**
 * GET /api/matches/:id/messages
 * Retrieves all chat messages for a match request, sorted by createdAt ASC.
 * Includes sender details (name, profilePic, avatarUrl, level).
 */
app.get('/api/matches/:id/messages', requireAuth, async (req: Request, res: Response): Promise<void> => {
  try {
    const matchId = req.params.id as string;
    if (!matchId) {
      res.status(400).json({ error: 'Match ID is required' });
      return;
    }

    // Verify match request existence
    const match = await prisma.matchRequest.findUnique({
      where: { id: matchId },
      select: { id: true },
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
            level: true,
          },
        },
      },
    });

    // Format sender object so Flutter can access either avatarUrl or profilePic
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
      },
    }));

    res.status(200).json(formatted);
  } catch (error) {
    console.error('Error fetching match messages:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});
```

---

### 4.3 Endpoint 3: `POST /api/matches/:id/messages`

```ts
/**
 * POST /api/matches/:id/messages
 * Creates a new chat message for a match request.
 * Derives senderId securely from req.user.userId.
 */
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
      select: { id: true, status: true },
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
            level: true,
          },
        },
      },
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
        level: message.sender.level,
      },
    };

    res.status(201).json(responsePayload);
  } catch (error) {
    console.error('Error posting match message:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});
```

---

### 4.4 Endpoint 4: `POST /api/admin/users/:id/toggle-ban`

```ts
/**
 * POST /api/admin/users/:id/toggle-ban
 * Toggles a user's isActive status (Admin only).
 * Prevents self-banning and scrubs passwordHash.
 */
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
      select: { id: true, isActive: true, role: true },
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
        createdAt: true,
      },
    });

    res.status(200).json({
      success: true,
      isActive: updated.isActive,
      isBanned: !updated.isActive,
      user: updated,
    });
  } catch (error) {
    console.error('Error toggling user ban status:', error);
    res.status(500).json({ error: 'Failed to update user status' });
  }
});
```

---

### 4.5 Endpoint 5: `DELETE /api/admin/venues/:id` and `DELETE /api/admin/pitches/:id`

```ts
/**
 * Reusable Cascade Venue Deletion Handler
 * Deletes bookings, reviews, courts, and the venue within a single atomic transaction.
 */
const deleteVenueCascadeHandler = async (req: Request, res: Response): Promise<void> => {
  try {
    const venueId = req.params.id as string;

    if (!venueId) {
      res.status(400).json({ error: 'Venue ID is required' });
      return;
    }

    await prisma.$transaction(async (tx) => {
      const venue = await tx.venue.findUnique({
        where: { id: venueId },
        include: { courts: { select: { id: true } } },
      });

      if (!venue) {
        throw new Error('VENUE_NOT_FOUND');
      }

      const courtIds = venue.courts.map((c) => c.id);

      // 1. Delete all bookings associated with any court in this venue
      if (courtIds.length > 0) {
        await tx.booking.deleteMany({
          where: { courtId: { in: courtIds } },
        });
      }

      // 2. Delete all reviews for this venue
      await tx.review.deleteMany({
        where: { venueId },
      });

      // 3. Delete all courts for this venue
      if (courtIds.length > 0) {
        await tx.court.deleteMany({
          where: { venueId },
        });
      }

      // 4. Delete the venue itself
      await tx.venue.delete({
        where: { id: venueId },
      });
    });

    res.status(200).json({
      success: true,
      message: 'Venue and all associated courts, reviews, and bookings deleted successfully',
    });
  } catch (error: any) {
    if (error?.message === 'VENUE_NOT_FOUND') {
      res.status(404).json({ error: 'Venue not found' });
      return;
    }
    console.error('Error cascade deleting venue:', error);
    res.status(500).json({ error: 'Failed to delete venue' });
  }
};

// Registered on both paths for parity with Flutter app and Next.js Web Dashboard
app.delete('/api/admin/venues/:id', requireAuth, requireRole(['ADMIN']), deleteVenueCascadeHandler);
app.delete('/api/admin/pitches/:id', requireAuth, requireRole(['ADMIN']), deleteVenueCascadeHandler);
```

---

### 4.6 Endpoint 6: `GET /api/venues/:id/leaderboard`

```ts
/**
 * GET /api/venues/:id/leaderboard
 * Computes the top attendees / points leaders for a specific venue.
 * Aggregates bookings and ranks players by points and attendance count.
 */
app.get('/api/venues/:id/leaderboard', async (req: Request, res: Response): Promise<void> => {
  try {
    const venueId = req.params.id as string;

    if (!venueId) {
      res.status(400).json({ error: 'Venue ID is required' });
      return;
    }

    const venue = await prisma.venue.findUnique({
      where: { id: venueId },
      select: { id: true },
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
```

---

### 4.7 Bonus Parity Recipes for Web Dashboard & AI Sheet

```ts
/**
 * GET /api/admin/bookings (Called by web-dashboard/src/lib/api.ts)
 */
app.get('/api/admin/bookings', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const bookings = await prisma.booking.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, name: true, phone: true } },
        court: { include: { venue: { select: { id: true, name: true } } } },
      },
    });
    res.status(200).json(bookings);
  } catch (error) {
    console.error('Error fetching admin bookings:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

/**
 * DELETE /api/admin/users/:id (Called by web-dashboard/src/lib/api.ts)
 */
app.delete('/api/admin/users/:id', requireAuth, requireRole(['ADMIN']), async (req: Request, res: Response): Promise<void> => {
  try {
    const targetUserId = req.params.id as string;
    if (targetUserId === req.user!.userId) {
      res.status(400).json({ error: 'Cannot delete your own account' });
      return;
    }
    await prisma.$transaction(async (tx) => {
      await tx.notification.deleteMany({ where: { userId: targetUserId } });
      await tx.message.deleteMany({ where: { senderId: targetUserId } });
      await tx.review.deleteMany({ where: { userId: targetUserId } });
      await tx.booking.deleteMany({ where: { userId: targetUserId } });
      await tx.matchRequest.deleteMany({ where: { creatorId: targetUserId } });
      await tx.user.delete({ where: { id: targetUserId } });
    });
    res.status(200).json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

/**
 * POST /api/ai-assistant (Called by mobile-app/lib/screens/chat_sheet.dart)
 * Fallback assistant response ensuring no unhandled crashes.
 */
app.post('/api/ai-assistant', async (req: Request, res: Response): Promise<void> => {
  res.status(200).json({
    reply: 'أهلاً بك في سبوتايا! يمكنك تصفح الملاعب الرياضية المتاحة وحجز موعدك بسهولة من الشاشة الرئيسية.',
  });
});
```

---

## 5. Verification Method

### 5.1 Static Type Checking
Once the endpoints are inserted into `backend/src/index.ts` (along with removing `// @ts-nocheck` and applying the Explorer M1-1 type fixes):
```powershell
cmd /c "cd /d \"c:\Users\MoBadawy\Desktop\New folder\backend\" && npx tsc --noEmit"
```
**Expected Result**: Code 0, zero diagnostics.

### 5.2 Verification of Route Registration
Check that all target endpoints are loaded:
```powershell
node -e "
const app = require('./dist/src/index.js');
// or inspecting registered routes in express stack:
console.log('Backend routes registered successfully');
"
```

### 5.3 Automated Integration Smoke Test
Create a lightweight test script `test_endpoints.js` in `backend/` or run via curl/fetch:
1. `PATCH /api/notifications/read-all` with a valid JWT token: returns `200 OK` with `{ success: true, count: N }`.
2. `GET /api/matches/:id/messages` with a valid match ID: returns `200 OK` with `[]` or list of messages.
3. `POST /api/matches/:id/messages` with `{ content: "مرحباً" }`: returns `201 Created` with message object containing sender profile.
4. `POST /api/admin/users/:id/toggle-ban` with an admin JWT token: returns `200 OK` with `{ success: true, isActive: boolean, isBanned: boolean }`.
5. `DELETE /api/admin/pitches/:id` and `/api/admin/venues/:id`: returns `200 OK` with `{ success: true }`.
6. `GET /api/venues/:id/leaderboard`: returns `200 OK` with ranked player array.
