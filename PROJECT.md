# Project: Spotaia Sports & Entertainment Platform

## Architecture
- **Backend Architecture**: Node.js, Express 5, TypeScript 5.9, Prisma ORM 5.0 connecting to PostgreSQL (Neon cloud / SQLite fallback), Firebase Admin v14 (modular push notifications), Stripe API, Multer upload engine.
- **Mobile Architecture**: Flutter 3.47.4, Dart 3.13.3, Riverpod 2.5 (state management), GoRouter 13.2 (declarative navigation), Dio 5.4 with global interceptors, OpenStreetMap with FlutterMap & LatLong2, Cairo typography, Dark Neon Futuristic Theme (`#0A0A0A`, `#121212`, `#00E5FF`, `#FF9100`).
- **Data Flow**:
  - Flutter Mobile App communicates via HTTP/JSON REST API with the Node.js backend.
  - JWT tokens stored in SharedPreferences and passed in `Authorization: Bearer <token>` header.
  - Backend verifies JWT, executes atomic business logic with Prisma transactions, and returns structured JSON responses `{ data }` or `{ error }`.
  - Push notifications dispatched asynchronously via Firebase Admin Cloud Messaging to device FCM tokens.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | User Registration & Role Control | Register Player/Owner; prevent unauthenticated Admin escalation | M1 | survey |
| 2 | User Login & JWT Auth | Authenticate user with phone & password, return JWT | M1 | survey |
| 3 | User Profile (`/auth/me`, `/users/me`) | Retrieve and update profile info, scrub passwordHash | M1 | survey |
| 4 | Fix Fatal Crash on `/auth/me` | Resolve ReferenceError: error is not defined in catch block | M1 | survey |
| 5 | TypeScript Compilation Safety | Remove `// @ts-nocheck` and resolve all 48 compiler errors | M1 | survey |
| 6 | Firebase Admin v14 Integration | Upgrade push notification logic to modular `firebase-admin` APIs | M1 | survey |
| 7 | Booking Concurrency & Double-Booking Lock | Implement atomic transaction check-and-create for court bookings | M1 | survey |
| 8 | Authorization & Ownership Enforcements | Secure booking status modification, attendance confirmation, court ops | M1 | survey |
| 9 | Missing Endpoint: Notifications Read-All | `PATCH /api/notifications/read-all` for user notifications | M1 | survey |
| 10 | Missing Endpoint: Match Chat Messages | `GET` and `POST /api/matches/:id/messages` for community game chat | M1 | survey |
| 11 | Missing Endpoint: Admin User Ban/Unban | `POST /api/admin/users/:id/toggle-ban` for account moderation | M1 | survey |
| 12 | Missing Endpoint: Admin Venue Deletion | `DELETE /api/admin/venues/:id` and `/api/admin/pitches/:id` | M1 | survey |
| 13 | Missing Endpoint: Venue Leaderboard | `GET /api/venues/:id/leaderboard` for venue top players | M1 | survey |
| 14 | Global JSON Error Handling (Backend) | Intercept syntax, Multer, and unhandled errors with clean JSON | M1 | survey |
| 15 | Cron Job Notification Deduplication | Prevent duplicate attendance reminders every 30 mins | M1 | survey |
| 16 | Multer File Upload Security | Enforce file size limits and image MIME type validation | M1 | survey |
| 17 | Flutter Unused Imports & Dead Code | Remove unused imports and dead functions (`_showEditProfileSheet`) | M2 | survey |
| 18 | Flutter Unused Variables & Unused Results | Remove unused variables (`isUnpaid`, `user`) and unused `ref.refresh()` | M2 | survey |
| 19 | Flutter Unnecessary Set Literals | Fix unnecessary set literals in `auth_screen.dart` | M2 | survey |
| 20 | Flutter Deprecated Member Migrations | Migrate `.withOpacity()`, `MaterialStateProperty`, `Share.share()` | M2 | survey |
| 21 | Flutter Async Gap BuildContext Guards | Add `if (!mounted) return;` across all async gaps | M2 | survey |
| 22 | Flutter Code Formatting & Const | Add `const` constructors and flow control braces across all screens | M2 | survey |
| 23 | Flutter Zero-Warning Gate | Pass `flutter analyze` with 0 issues | M2 | survey |
| 24 | Fix Fatal `RenderFlex` Layout Crash | Fix unconstrained `Expanded` inside `Row` in `home_screen.dart` | M3 | survey |
| 25 | Memory Leak Elimination (Controller Disposal) | Implement `dispose()` on all 4 form screens (`TextEditingController`) | M3 | survey |
| 26 | Tab State Retention (`IndexedStack`) | Use `IndexedStack` in `HomeScreen` to preserve tab scroll/state | M3 | survey |
| 27 | Centralized API URL Configuration | Eliminate hardcoded `192.168.1.10:3001` in 6 screens into config | M3 | survey |
| 28 | Standardized User-Facing Error Boundary | Replace raw `Text('خطأ: $err')` with dark neon error widget + retry | M3 | survey |
| 29 | Offline Session Resilience | Prevent `SplashScreen` from dropping login session on network drop | M3 | survey |
| 30 | UI Empty-State Polish | Add custom Arabic empty state cards for venues, bookings, alerts | M3 | survey |
| 31 | Unit & Widget Smoke Test Suite | Replace broken starter test with genuine `SpotaiaApp` smoke test | M3 | survey |
| 32 | E2E Test Infrastructure | Build opaque-box automated test harness for all API endpoints | M4 | survey |
| 33 | E2E Test Tier 1: Feature Coverage | Verify Auth, Venues, Courts, Bookings, Reviews, Matches, Admin | M4 | survey |
| 34 | E2E Test Tier 2: Boundary & Edge Cases | Verify overnight slots, double-booking rejection, past times, auth guards | M4 | survey |
| 35 | E2E Test Tier 3: Cross-Feature Interactions | Verify Booking -> Points award -> Attendance -> Review gate | M4 | survey |
| 36 | E2E Test Tier 4: Real-World Scenarios | Complete end-to-end player booking & owner management workflows | M4 | survey |
| 37 | Offline & Network Failure Simulation | Verify graceful degradation when backend is unreachable | M4 | survey |
| 38 | Android Gradle Wrapper Upgrade | Upgrade wrapper to Gradle 8.14.0 (matching Flutter 3.47.4) | M5 | survey |
| 39 | Android JDK 17 Configuration | Set `org.gradle.java.home` to bundled `jdk17/jdk-17.0.12+7` | M5 | survey |
| 40 | Android Permissions & Cleartext Config | Add `POST_NOTIFICATIONS`, `CAMERA`, `READ_MEDIA_IMAGES`, cleartext traffic | M5 | survey |
| 41 | Production Release APK Compilation | Execute `flutter build apk --release` and verify output binary | M5 | survey |
| 42 | Final Victory Audit & Acceptance Report | Verify all 5 acceptance criteria and publish markdown report | M6 | survey |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Backend Production Refactoring & Type Safety | `backend/` | none | IN_PROGRESS |
| M2 | Flutter Static Analysis & Zero-Issue Compliance | `mobile-app/lib/` | none | PLANNED |
| M3 | Flutter UX/UI, Memory Leak & Error Handling Polish | `mobile-app/lib/` | M1, M2 | PLANNED |
| M4 | Dual Track E2E Testing & Robustness Verification | `backend/`, test harness | M1 | PLANNED |
| M5 | Android Build Toolchain & Release APK Compilation | `mobile-app/android/`, build | M2, M3 | PLANNED |
| M6 | Final Verification, Victory Audit & Comprehensive Report | Root & reports | M1, M2, M3, M4, M5 | PLANNED |

## Interface Contracts
### Client ↔ Backend REST API
- **Auth**:
  - `POST /api/auth/register`: `{ name, phone, password, role? }` -> `{ user: { id, name, phone, role, points, tier }, token }` (400 if phone exists, role restricted to PLAYER unless admin).
  - `POST /api/auth/login`: `{ phone, password }` -> `{ user: { id, name, phone, role, points, tier }, token }` (401 on bad credentials).
  - `GET /api/auth/me`: Auth Header -> `{ id, name, phone, role, points, tier, profilePic }` (401 on invalid token).
- **Venues & Courts**:
  - `GET /api/venues`: Query -> `Venue[]` with courts and starting prices.
  - `GET /api/venues/:id`: -> `Venue` with full details, courts, reviews.
  - `POST /api/venues`: Owner/Admin Auth -> Created `Venue`.
  - `POST /api/venues/:id/courts`: Owner/Admin Auth -> Created `Court`.
  - `PATCH /api/courts/:id`: Owner/Admin Auth -> Updated `Court`.
  - `DELETE /api/courts/:id`: Owner/Admin Auth -> Success message.
  - `GET /api/venues/:id/leaderboard`: -> `Player[]` ranked by points.
- **Bookings**:
  - `POST /api/bookings`: `{ courtId, startTime, endTime }` -> Atomic transaction check: 400 if occupied, 201 with `Booking` if successful.
  - `GET /api/bookings`: Auth Header -> User's bookings list.
  - `PATCH /api/bookings/:id/status`: Auth Header (Owner of court, Creator of booking, or Admin) -> `{ status: 'CONFIRMED'|'REJECTED'|'CANCELLED' }`.
  - `POST /api/bookings/:id/confirm-attendance`: Auth Header (Booking Creator only) -> Updated booking with `ATTENDANCE_CONFIRMED`.
- **Community & Chat**:
  - `GET /api/match-requests`: -> Open `MatchRequest[]`.
  - `POST /api/match-requests`: `{ title, description, matchTime, missingSpots, costPerSpot }` -> Created `MatchRequest`.
  - `GET /api/matches/:id/messages`: Auth Header -> `Message[]` sorted by `createdAt ASC`.
  - `POST /api/matches/:id/messages`: Auth Header, `{ content }` -> Created `Message`.
- **Notifications**:
  - `GET /api/notifications`: Auth Header -> `Notification[]`.
  - `PATCH /api/notifications/read-all`: Auth Header -> `{ success: true, count: N }`.
- **Admin**:
  - `GET /api/admin/stats`: Admin Auth -> `{ totalUsers, totalVenues, totalBookings, totalRevenue }`.
  - `GET /api/admin/users`: Admin Auth -> `User[]` (without passwordHash).
  - `POST /api/admin/users/:id/toggle-ban`: Admin Auth -> `{ success: true, isBanned: boolean }`.
  - `DELETE /api/admin/venues/:id`: Admin Auth -> Cascade delete venue.
- **Error Format**:
  - All endpoints return `{ error: string }` with appropriate HTTP status codes (400, 401, 403, 404, 500) and never HTML stack traces.

## Code Layout
- `backend/`: Node.js/TypeScript backend server.
  - `src/index.ts`: Application entry point.
  - `src/config/`: Configuration & environment loading.
  - `src/lib/`: Prisma client, Firebase Admin, utilities.
  - `src/middlewares/`: Auth, role verification, multer, global error handler.
  - `src/controllers/`: Route business logic controllers.
  - `src/routes/`: Express route definitions.
  - `prisma/`: Prisma schema and migrations.
- `mobile-app/`: Flutter mobile application.
  - `lib/main.dart`: Root entry point & GoRouter configuration.
  - `lib/core/config/`: App configuration & dynamic base URL.
  - `lib/core/theme/`: Dark Neon theme & typography.
  - `lib/core/widgets/`: Reusable dark-neon error boundaries, empty states, loading indicators.
  - `lib/models/`: Strongly typed Dart data models.
  - `lib/providers/`: Riverpod providers & Dio API client.
  - `lib/screens/`: Flutter UI screens.
  - `android/`: Native Android project, Gradle build scripts, AndroidManifest.xml.
  - `test/`: Flutter unit and widget smoke tests.
