# Backend Codebase Architecture & Audit Report (Spotaia Backend)

## 1. Observation

### 1.1 Architecture & Project Layout
- **Root Location**: `c:\Users\MoBadawy\Desktop\New folder\backend\`
- **Monolith Structure**: The entire backend application is currently contained within a single monolithic file: `backend/src/index.ts` (660 lines).
- **Abandoned Modular Directories**:
  - `backend/src/controllers/` (Empty directory)
  - `backend/src/middlewares/` (Empty directory)
  - `backend/src/routes/` (Empty directory)
  - `backend/src/utils/` (Empty directory)
- **Legacy / Serverless File**: `backend/api/[...path].ts` (271 lines) and `backend/api/hello.js` (4 lines). `api/[...path].ts` contains obsolete endpoints referring to a non-existent `Pitch` model.
- **Dependencies (`backend/package.json`)**:
  - Runtime: `@neon/config` (v1.5.0), `@neon/env` (v1.3.4), `@prisma/client` (v5.0.0), `axios` (v1.20.0), `bcryptjs` (v3.0.3), `cors` (v2.8.6), `dotenv` (v17.4.2), `express` (v5.2.1), `firebase-admin` (v14.4.0), `jsonwebtoken` (v9.0.3), `multer` (v2.4.0), `node-cron` (v4.6.0), `openai` (v7.15.0), `prisma` (v5.0.0), `stripe` (v22.6.2), `zod` (v4.6.5).
  - Dev: `@types/bcryptjs` (v2.4.6), `@types/cors` (v2.8.19), `@types/express` (v5.0.6), `@types/jsonwebtoken` (v9.0.10), `@types/multer` (v2.2.0), `@types/node` (v22.20.3), `@types/node-cron` (v3.0.11), `nodemon` (v3.1.14), `ts-node` (v10.9.2), `typescript` (v5.9.3).
  - Scripts: `"build": "tsc"`, `"postinstall": "prisma generate"`, `"start": "node dist/src/index.js"`, `"dev": "nodemon src/index.ts"`. Note: No test script defined (`"test": "echo \"Error: no test specified\" && exit 1"`).
- **Database Schema (`backend/prisma/schema.prisma`)**:
  - PostgreSQL hosted on Neon (`ep-holy-sunset-b426camg-pooler.c-6.us-east-2.aws.neon.tech/neondb`).
  - Models: `User`, `Venue`, `Court`, `Booking`, `Review`, `Notification`, `MatchRequest`, `Message`.
  - Database status: Active with live records: 73 users, 22 venues, 44 courts, 164 bookings, 1 match request, 23 notifications.

---

### 1.2 TypeScript Compilation Status & `@ts-nocheck` Masking
When running `cmd /c "npx tsc --noEmit"`, the compiler exits with code `0`.
**However, this is completely artificial**: Line 1 of `backend/src/index.ts` and Line 1 of `backend/api/[...path].ts` both contain:
```ts
// @ts-nocheck
```
When `// @ts-nocheck` is removed, TypeScript reports **48 compile errors in `src/index.ts`** and **11 compile errors in `api/[...path].ts`** (Total 59 diagnostics).

#### Verbatim Compiler Errors in `backend/src/index.ts`:
1. **Broken Identifier / Runtime Crash**:
   - `[Line 164:19] Cannot find name 'error'. Did you mean 'Error'?`
   Line 163-165:
   ```ts
   } catch (e) {
     console.error(error); res.status(500).json({ error: 'Server error' });
   }
   ```
   *Impact*: If an error occurs in `GET /api/auth/me`, Node throws `ReferenceError: error is not defined`, crashing the server process.

2. **Firebase Admin v14 API Mismatches**:
   - `[Line 51:14] Property 'apps' does not exist on type 'typeof import(".../firebase-admin/lib/index")'`
   - `[Line 52:45] Property 'credential' does not exist on type 'typeof import(".../firebase-admin/lib/index")'`
   - `[Line 400:21] Property 'messaging' does not exist on type 'typeof import(".../firebase-admin/lib/index")'`
   - `[Line 548:27] Property 'messaging' does not exist on type 'typeof import(".../firebase-admin/lib/index")'`
   - `[Line 560:27] Property 'messaging' does not exist on type 'typeof import(".../firebase-admin/lib/index")'`
   - `[Line 599:21] Property 'messaging' does not exist on type 'typeof import(".../firebase-admin/lib/index")'`
   - `[Line 643:23] Property 'messaging' does not exist on type 'typeof import(".../firebase-admin/lib/index")'`
   *Impact*: Firebase Admin v14 uses modular sub-packages (`firebase-admin/app`, `firebase-admin/messaging`). Calling `admin.messaging()` throws `TypeError: admin.messaging is not a function`.

3. **Stripe API Version Mismatch**:
   - `[Line 43:79] Type '"2025-01-27.acacia"' is not assignable to type '"2026-08-26.dahlia"'`
   *Impact*: Stripe package v22.6.2 types require `'2026-08-26.dahlia'`.

4. **Express 5 Parameter Typing & Prisma Generic Breakdown**:
   - Express 5 types `req.params.id` as `string | string[]`.
   - Passing `req.params.id` without narrowing (`req.params.id as string`) causes 16 type errors where Prisma expects `string`:
     - Lines 218, 259, 261, 263, 277, 299, 309, 321, 326, 327, 338, 523, 533, 574, 584.
   - Because the `where` clause fails type checking, Prisma's TypeScript inference defaults to base models without relation fields, producing 24 cascading relation errors:
     - `Property 'court' does not exist on type 'GetResult<...>'` (Lines 543, 548, 553, 555, 559, 560, 590, 592, 597, 600, 601).
     - `Property 'user' does not exist on type 'GetResult<...>'` (Lines 547, 548, 555, 560, 592, 601).
     - `Property 'courts' does not exist on type 'GetResult<...>'` (Line 230).
     - `Property 'venue' does not exist on type 'GetResult<...>'` (Lines 300, 322).

5. **Prisma Aggregate Return Type Mismatch**:
   - `[Line 264:72] Property 'id' does not exist on type 'true | ...'`
   Line 261-264: `const aggr = await prisma.review.aggregate({ _avg: { rating: true }, _count: { id: true }, where: { venueId } });` -> `totalReviews: aggr._count.id`.

6. **`app.listen` Overload Mismatch**:
   - `[Line 655:12] Argument of type 'string | 3001' is not assignable to parameter of type 'number'`
   `const PORT = process.env.PORT || 3001` has type `string | number`.

---

### 1.3 Critical Logical Bugs & Security Vulnerabilities

1. **Privilege Escalation in Registration (`src/index.ts:116-133`)**:
   ```ts
   app.post('/api/auth/register', async (req: Request, res: Response) => {
     const { name, phone, password, role } = req.body;
     ...
     const user = await prisma.user.create({
       data: { name, phone, passwordHash, role: role || 'PLAYER' }
     });
   ```
   *Vulnerability*: An unauthenticated public user can pass `role: 'ADMIN'` in the request body to create a super admin account.

2. **Broken Authorization in Booking Status Modification (`src/index.ts:517-568`)**:
   ```ts
   app.patch('/api/bookings/:id/status', requireAuth, async (req: Request, res: Response) => {
     const bookingId = req.params.id;
     const { status } = req.body;
     const booking = await prisma.booking.findUnique({ where: { id: bookingId } ... });
     const updated = await prisma.booking.update({ where: { id: bookingId }, data: { status } });
   ```
   *Vulnerability*: Any authenticated user can modify the status of ANY booking in the entire database (e.g. cancelling or rejecting competitors' bookings). There is NO verification that `req.user.userId === booking.userId` or `req.user.userId === booking.court.venue.ownerId` or `req.user.role === 'ADMIN'`.

3. **Broken Authorization in Attendance Confirmation (`src/index.ts:570-610`)**:
   `POST /api/bookings/:id/confirm-attendance` does NOT check if `req.user.userId === booking.userId`. Any user can mark another player's attendance as confirmed.

4. **Admin Lockout in Court Management (`src/index.ts:273-333`)**:
   In `POST /api/venues/:id/courts`, `PATCH /api/courts/:id`, and `DELETE /api/courts/:id`:
   ```ts
   if (!venue || venue.ownerId !== req.user!.userId) {
     res.status(403).json({ error: 'Forbidden' });
     return;
   }
   ```
   Even though the middleware is `requireRole(['OWNER', 'ADMIN'])`, the controller logic strictly enforces `venue.ownerId === req.user.userId`. Super Admins are blocked from managing or deleting courts created by owners.

5. **Double-Booking Race Condition (`src/index.ts:355-411`)**:
   `POST /api/bookings` runs a non-atomic `prisma.booking.findFirst()` overlap query, calculates fees in JS, and then runs `prisma.booking.create()`. Under concurrent requests, two users can book the exact same court and time slot simultaneously. The specification in `spotaia_specs.txt` claims pessimistic locking (`SELECT ... FOR UPDATE`), but it was never implemented.

6. **Firebase Initialization Failures (`src/index.ts:49-54`)**:
   ```ts
   try {
     const serviceAccount = require('../../firebase-admin.json');
     if (!admin.apps.length) {
       admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
     }
   } catch (e) {}
   ```
   - In development, `../../firebase-admin.json` looks in `c:\Users\MoBadawy\Desktop\firebase-admin.json`, which does not exist (the file is at `backend/firebase-admin.json`).
   - In `firebase-admin` v14, `admin.apps` and `admin.credential` are undefined.
   - The entire block throws and gets swallowed by `catch (e) {}`, leaving Firebase completely uninitialized.

7. **Notification Spam Loop in Cron Job (`src/index.ts:613-653`)**:
   Cron job runs every 30 minutes (`*/30 * * * *`) and queries all confirmed bookings starting within the next 1 hour. It creates a database notification and sends push notifications on each execution, with NO deduplication check (`reminderSent`). As a result, users receive duplicate reminders every 30 minutes until their booking starts.

8. **Password Hash Leakage**:
   - `POST /api/auth/register` returns `{ user, token }` containing `user.passwordHash`.
   - `POST /api/auth/login` returns `{ user, token }` containing `user.passwordHash`.
   - `GET /api/auth/me` returns `user` containing `passwordHash`.
   - `PUT /api/users/me` returns `user` containing `passwordHash`.
   - `GET /api/admin/users` returns all users with their `passwordHash`.

9. **Missing `dotenv.config()` Call**:
   `src/index.ts` never calls `dotenv.config()`. Unless environment variables are already set in the operating system shell, `process.env.DATABASE_URL`, `process.env.JWT_SECRET`, and `OPENAI_API_KEY` are undefined in standard Node.js runtime execution.

10. **Memory Leak / Overfetching in Data Queries**:
    - `GET /api/venues`: Fetches every venue, every court, and ALL bookings ever made (`where: { status: { in: ['CONFIRMED', 'PENDING', 'ATTENDANCE_CONFIRMED'] } }`). Loading historical bookings for all venues into Node.js RAM causes severe latency and memory exhaustion.
    - `GET /api/admin/stats`: Loads all completed bookings into an in-memory array to run `.reduce()` in JavaScript instead of using Prisma `aggregate._sum`.

11. **Unrestricted File Upload (`POST /api/upload`)**:
    Multer disk storage has no `limits.fileSize` limit and no `fileFilter` on MIME type or extension, allowing arbitrary file execution / disk saturation DoS.

---

### 1.4 Route Parity & Missing Endpoints Required by Frontend / Web Dashboard

| Endpoint | Called By | Implemented in `backend/src/index.ts`? | Status / Impact |
|---|---|---|---|
| `GET /api/matches/:id/messages` | `mobile-app/lib/screens/chat_screen.dart:41` | ❌ No | Screen polls every 3s; returns 404 |
| `POST /api/matches/:id/messages` | `mobile-app/lib/screens/chat_screen.dart:75` | ❌ No | Sending match chat messages fails |
| `POST /api/ai-assistant` | `mobile-app/lib/screens/chat_sheet.dart:31` | ❌ No | Astra AI chat fails ("حدث خطأ في الاتصال بالمساعد الذكي") |
| `PATCH /api/notifications/read-all` | `mobile-app/lib/screens/notifications_screen.dart:24` | ❌ No | Marking notifications as read fails (404) |
| `POST /api/admin/users/:id/toggle-ban` | `mobile-app/lib/screens/admin_dashboard_screen.dart:266` | ❌ No | Admin ban/unban button fails (404) |
| `DELETE /api/admin/pitches/:id` | `mobile-app/lib/screens/admin_dashboard_screen.dart:373` & `web-dashboard` | ❌ No | Deleting venues by admin fails (404) |
| `DELETE /api/admin/venues/:id` | `web-dashboard/src/lib/api.ts` | ❌ No | Admin venue deletion fails |
| `GET /api/admin/bookings` | `web-dashboard/src/lib/api.ts:15` | ❌ No | Dashboard bookings view fails |
| `DELETE /api/admin/users/:id` | `web-dashboard/src/lib/api.ts:18` | ❌ No | Admin user deletion fails |
| `GET /api/venues/:id/leaderboard` | `mobile-app/lib/providers/api_provider.dart:63` | ❌ No | Venue leaderboard fails |

---

### 1.5 Error Handling Across All Routes
- **No Global Error Handler**: Express has no `app.use((err, req, res, next) => ...)` middleware.
- **Leaked Stack Traces & HTML Responses**: When Multer triggers an error (e.g. `LIMIT_UNEXPECTED_FILE` when more than 5 images are sent) or JSON parser encounters malformed JSON, Express 5 defaults to sending an HTML error page with raw stack traces rather than a structured JSON error response `{ error: string }`.
- **No Catch-All 404 Handler**: Unknown routes return Express default HTML `Cannot GET /...`.
- **No Process Handlers**: `process.on('unhandledRejection')` and `process.on('uncaughtException')` are not set.

---

## 2. Logic Chain

1. **Premise**: Production acceptance criteria R1 and R3 require passing static analysis (`tsc --noEmit`), eliminating runtime bugs, and ensuring error boundaries without crashing or raw exceptions.
2. **Step 1 (TypeScript Masking)**: The compiler passing with 0 errors was achieved by placing `// @ts-nocheck` on line 1 of `backend/src/index.ts`. When evaluated under standard TypeScript compilation rules, 48 distinct compilation and type-safety errors are present in `src/index.ts`.
3. **Step 2 (Runtime Failure Vulnerability)**: Line 164 contains `console.error(error)` inside `catch (e)`. Because `error` is undeclared in this scope, any error during `GET /api/auth/me` will throw an unhandled `ReferenceError`, directly crashing the server process.
4. **Step 3 (Integration Breakdown)**: In `src/index.ts`, Firebase Admin was updated to v14 in `package.json`, but the legacy v9/v10 syntax (`admin.messaging()`, `admin.apps`, `admin.credential`) was kept. The initialization fails inside an empty catch block, and subsequent push notification attempts throw runtime TypeErrors. In `broadcast.js`, the proper modular syntax (`firebase-admin/messaging` and `firebase-admin/app`) was discovered by the developer but never backported to `src/index.ts`.
5. **Step 4 (Frontend Disconnection)**: Flutter mobile app screens actively call endpoints (`/matches/:id/messages`, `/ai-assistant`, `/notifications/read-all`, `/admin/users/:id/toggle-ban`, `/admin/pitches/:id`) that were never registered in `backend/src/index.ts`. The mobile app receives continuous 404 HTTP errors.
6. **Step 5 (Security Exposure)**: Registration lacks role verification, enabling any caller to self-assign `ADMIN`. Booking cancellation endpoints lack identity verification, allowing any authenticated user to cancel or reject any booking across the platform.

---

## 3. Caveats
- Neon PostgreSQL database was investigated via non-destructive queries; no schema changes or data modifications were made during this survey.
- Firebase FCM tokens stored in the database were not sent real push notifications during this read-only audit to avoid spamming real test devices.
- The external AI endpoint configured in `.env` (`OPENAI_BASE_URL=https://kie.ai/codex/v1` with model `gpt-6-astra`) was verified by inspecting `.env` and `chat_sheet.dart`, but no live API credits were consumed.

---

## 4. Conclusion & Actionable Blueprint

The backend requires a structured refactoring from the current 660-line monolith into the clean modular architecture already prepared in the directory tree:

```
backend/src/
├── config/
│   └── env.ts                 # dotenv loader, validated env variables, constants
├── lib/
│   ├── prisma.ts              # Singleton Prisma client instance
│   ├── firebase.ts            # Firebase Admin v14 initialization & safe push helper
│   └── ai.ts                  # OpenAI / Astra assistant integration helper
├── middlewares/
│   ├── auth.ts                # requireAuth, requireRole, strict Express.Request types
│   ├── upload.ts              # Multer with size limits, MIME filtering, error wrapper
│   └── errorHandler.ts        # Global error handler returning clean JSON, 404 handler
├── controllers/
│   ├── authController.ts      # register (secure), login, me, updateProfile, leaderboard
│   ├── venueController.ts     # list, getById, create, reviews, deleteVenue
│   ├── courtController.ts     # createCourt, patchCourt, deleteCourt, getById
│   ├── bookingController.ts   # createBooking (atomic transaction), list, status, attendance
│   ├── matchController.ts     # matchRequests, createMatch, listMessages, postMessage
│   ├── notificationController.ts # listNotifications, readAllNotifications
│   ├── adminController.ts     # stats (aggregate), users, toggleBan, deleteUser, venues, deleteVenue
│   └── aiController.ts        # /api/ai-assistant endpoint
├── routes/
│   ├── authRoutes.ts
│   ├── venueRoutes.ts
│   ├── courtRoutes.ts
│   ├── bookingRoutes.ts
│   ├── matchRoutes.ts
│   ├── notificationRoutes.ts
│   ├── adminRoutes.ts
│   ├── aiRoutes.ts
│   └── uploadRoutes.ts
├── jobs/
│   └── reminderCron.ts        # Deduplicated attendance reminder cron
└── index.ts                   # Clean app bootstrapping (< 50 lines)
```

### Specific Implementation Requirements for Phase 1:
1. **Remove `// @ts-nocheck`** across all backend files and resolve all 48 type errors.
2. **Exclude or delete obsolete `api/[...path].ts`** from `tsconfig.json` (`include: ["src/**/*"]`).
3. **Implement Concurrency-Safe Bookings**: Use Prisma `$transaction` with overlap check and booking creation, or PostgreSQL row locking.
4. **Fix Firebase SDK**: Use `initializeApp`, `cert`, and `getMessaging()` from `firebase-admin/app` and `firebase-admin/messaging`.
5. **Implement Missing Endpoints**: Add `/api/matches/:id/messages` (GET/POST), `/api/ai-assistant` (POST), `/api/notifications/read-all` (PATCH), `/api/admin/users/:id/toggle-ban` (POST), and `/api/admin/venues/:id` (DELETE).
6. **Enforce Role & Ownership Authorization**: Restrict registration role to `PLAYER` (only existing admins can create admins); restrict booking status changes to the booking owner, venue owner, or admin.
7. **Scrub `passwordHash`**: Exclude `passwordHash` from all user responses.
8. **Add Global JSON Error Handling**: Intercept all errors, Multer limits, and syntax errors, returning `{ error: message }` without stack traces.

---

## 5. Verification Method

### 5.1 Independent Compilation Check
To verify the true compilation status of the backend without `@ts-nocheck`:
```powershell
# Run the diagnostic script in the survey folder:
node "c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\explorer_backend_survey\check_ts.js"
```
Or directly edit `src/index.ts` to remove `// @ts-nocheck` on line 1, and run:
```powershell
cmd /c "npx tsc --noEmit"
```
*Expected Result*: Exits with code 0 only after all 48 type mismatches and missing imports are properly resolved.

### 5.2 Verification of Bug at Line 164 (`ReferenceError: error is not defined`)
Inspect `backend/src/index.ts` lines 163-165:
```ts
} catch (e) {
  console.error(error); res.status(500).json({ error: 'Server error' });
}
```
*Verification*: Notice that `catch (e)` captures identifier `e`, but line 164 evaluates `error`, which does not exist in local or module scope.

### 5.3 Verification of Missing Endpoints in Mobile App
Grep mobile app for endpoints:
```powershell
# In mobile-app/lib:
Select-String -Path "mobile-app\lib\screens\*.dart" -Pattern "ai-assistant", "messages", "read-all", "toggle-ban"
```
*Verification*: Shows calls in `chat_sheet.dart`, `chat_screen.dart`, `notifications_screen.dart`, and `admin_dashboard_screen.dart`. Comparing these with route handlers in `backend/src/index.ts` confirms they are missing.
