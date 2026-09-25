# Spotaia — Comprehensive Specification Survey & Feature Inventory

> **Author**: Specification Miner Agent
> **Date**: 2026-09-25T11:05:00+03:00
> **Target System**: Spotaia Sports & Entertainment Booking Ecosystem (Flutter Mobile App + Node.js Backend + Next.js Web Dashboard)
> **Working Directory**: `c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\spec_miner_survey`

---

## 1. Observation

Direct code and documentation observations gathered during repository and specification mining:

1. **Authoritative Specification Documents**:
   - `ORIGINAL_REQUEST.md`: End-to-end audit, UX/UI enhancement, zero-warning static analysis (`flutter analyze` 0 issues, backend `tsc --noEmit`), clean release APK build (`flutter build apk --release`), robust error handling without raw exceptions.
   - `spotaia_specs.txt`: Spotaia branding ("Dark Neon Futuristic Sports", `#121212`, `#0A0A0A`, Neon Blue `#00E5FF`, Neon Orange `#FF9100`), Riverpod, GoRouter, Dio, pessimistic concurrency locking against double bookings, gamification points (50 pts / booking, Bronze/Silver/Gold/Diamond), review system with verified booking gate, owner dashboard.
   - `PITCHUP_COMPLETE_GUIDE.txt`: 10% platform commission model, strict exclusion of user-facing AI tools or technical server settings, role-based workflows (PLAYER, OWNER, ADMIN), multi-platform deployment roadmap.
   - `implementation_plan.md`: Strict booking lifecycle (`PENDING` -> Owner `CONFIRMED` or `REJECTED` -> Player `ATTENDANCE_CONFIRMED`), attendance reminder cron job, in-app notifications.
   - `handoff.txt`: Database schema history, transition from Pitch model to Venue & Court hierarchical model, manual slot blocking by owners.

2. **Codebase Realities**:
   - **Backend (`backend/src/index.ts`)**:
     - Prisma models: `User`, `Venue`, `Court`, `Booking`, `Review`, `Notification`, `MatchRequest`, `Message`.
     - Endpoints implemented: `/api/upload`, `/api/auth/register`, `/api/auth/login`, `/api/auth/me`, `/api/users/me`, `/api/users/leaderboard`, `/api/venues`, `/api/venues/:id`, `/api/venues/:id/reviews`, `/api/venues/:id/courts`, `/api/courts/:id` (PATCH, DELETE, GET), `/api/bookings` (POST, GET), `/api/match-requests` (GET, POST), `/api/admin/stats`, `/api/admin/users`, `/api/admin/venues`, `/api/notifications` (GET), `/api/bookings/:id/status` (PATCH), `/api/bookings/:id/confirm-attendance` (POST), cron job every 30 mins for attendance reminders.
     - Line 1 contains `// @ts-nocheck`, which suppresses TypeScript compiler checks.
     - **Missing endpoints**:
       - `PATCH /api/notifications/read-all` (called by Flutter `NotificationsScreen.dart:24`).
       - `GET /api/matches/:id/messages` and `POST /api/matches/:id/messages` (called by Flutter `ChatScreen.dart:41,75`).
       - `GET /api/venues/:id/leaderboard` (declared in `api_provider.dart:63`).
   - **Flutter Mobile App (`mobile-app/`)**:
     - 22 Dart files including 16 active UI screens (`splash_screen.dart`, `onboarding_screen.dart`, `auth_screen.dart`, `home_screen.dart`, `venue_details_screen.dart`, `court_booking_screen.dart`, `court_schedule_screen.dart`, `add_venue_screen.dart`, `add_court_screen.dart`, `manage_venue_screen.dart`, `owner_dashboard_screen.dart`, `admin_dashboard_screen.dart`, `notifications_screen.dart`, `chat_screen.dart`, `location_picker_screen.dart`, `map_screen.dart`, `add_match_request_screen.dart`, `edit_profile_screen.dart`).
     - Hardcoded API IP `http://192.168.1.10:3001` hardcoded across 6 UI files (`home_screen.dart:22`, `venue_details_screen.dart:14`, `court_booking_screen.dart:13`, `owner_dashboard_screen.dart:19`, `admin_dashboard_screen.dart:12`, `edit_profile_screen.dart:12`) in local helper function `getFullUrl()` instead of referencing `dioProvider` or a centralized config.
     - `flutter analyze` currently reports **116 issues** (deprecated `.withOpacity()`, deprecated `Share.share()`, unused imports, unused local variables, async gap BuildContext warnings, formatting, and missing const constructors).
     - `test/widget_test.dart` contains a legacy counter test that fails (`flutter test` fails with code 1).
     - Android environment: Flutter 3.47.4, Dart 3.13.3, Android SDK 36.0.0, OpenJDK 17.0.12 in `jdk17/jdk-17.0.12+7`.
   - **Web Admin Dashboard (`web-dashboard/`)**:
     - Next.js app calling outdated `/api/pitches` instead of `/api/venues`.

---

## 2. Logic Chain

1. **System Invariant**: Spotaia operates as a two-sided marketplace for sports/entertainment venue bookings with gamification and community matchmaking.
2. **Contract Disconnect**:
   - The Flutter frontend expects message endpoints (`/matches/:id/messages`) and notification read-all (`/notifications/read-all`), but the backend does not expose them, creating runtime 404 errors during community chat and notifications.
   - The Flutter app has hardcoded local IP addresses in helper functions, causing broken images when connecting to any backend other than `192.168.1.10`.
3. **Acceptance Criteria Gates**:
   - `flutter analyze` must drop from 116 issues to 0. All 116 issues are mechanical lint and deprecation fixes (e.g. `withValues(alpha: ...)`, `SharePlus`, removing unused variables/imports, adding `mounted` guards).
   - `test/widget_test.dart` must be replaced with relevant widget/smoke tests for Spotaia (such as verifying `SpotaiaApp` boots without throwing exceptions).
   - Backend `// @ts-nocheck` must be safely validated or removed to ensure strict TypeScript compilation.
   - Release APK build requires JDK 17 (available at `c:\Users\MoBadawy\Desktop\New folder\jdk17\jdk-17.0.12+7`) and proper cleartext network permissions if pointing to local IP.

---

## 3. Caveats

1. The codebase uses SQLite in local dev (`backend/prisma/dev.db`), but the Prisma schema specifies `postgresql` provider pointing to `DATABASE_URL`. Neon PostgreSQL connection is required for cloud deployment.
2. Firebase Admin SDK (`firebase-admin.json`) is present for push notifications; in development without active FCM keys, FCM calls are safely wrapped in try/catch blocks.
3. No AI tools should be exposed to end users per explicit product requirements in `PITCHUP_COMPLETE_GUIDE.txt`. The legacy `chat_sheet.dart` file should remain decoupled or removed.

---

## 4. Conclusion

The Spotaia application possesses a complete, rich feature set spanning sports booking, multi-court venues, gamification, leaderboard, community matchmaking, interactive OpenStreetMap, role-based dashboards, and attendance confirmation. However, it currently suffers from:
1. 116 static analysis lint/deprecation issues in Flutter.
2. 3 missing backend REST endpoints required by the mobile app (messages, notifications read-all, venue leaderboard).
3. Hardcoded local IP addresses bypassing configuration in 6 screens.
4. A failing default template test in `widget_test.dart`.

Addressing these specific discrepancies will allow the app to satisfy 100% of acceptance criteria and produce a clean production-grade release APK.

---

## 5. Verification Method

To verify the findings and current system health:
1. **Analyze Flutter Codebase**:
   ```powershell
   cmd /c "C:\Entertainment\sdk\flutter\bin\flutter.bat analyze"
   ```
   *Expected Current Output*: 116 issues found.
2. **Verify TypeScript Compilation**:
   ```powershell
   cmd /c "npx tsc --noEmit"  # in backend directory
   ```
   *Expected Current Output*: Exits 0 (currently masked by `// @ts-nocheck`).
3. **Verify Flutter Test Suite**:
   ```powershell
   cmd /c "C:\Entertainment\sdk\flutter\bin\flutter.bat test"
   ```
   *Expected Current Output*: Fails on `Counter increments smoke test`.
4. **Inspect Flutter Doctor & JDK**:
   ```powershell
   cmd /c "C:\Entertainment\sdk\flutter\bin\flutter.bat doctor -v"
   ```
   *Expected Current Output*: Android SDK 36.0.0, OpenJDK 17.0.12 detected.

---

# Comprehensive Feature Inventory

## Features Discovered

| # | Category | Feature | Description | Inputs | Outputs | Error Behavior | Discovered Via |
|---|----------|---------|-------------|--------|---------|----------------|----------------|
| 1 | Auth & User | User Registration | Registers a new account as Player or Venue Owner | `name`, `phone`, `password`, `role` (PLAYER/OWNER) | User object, JWT token | Returns 400 if phone already registered | `backend/src/index.ts:116`, `auth_screen.dart` |
| 2 | Auth & User | User Login | Authenticates existing user by phone & password | `phone`, `password` | User profile, JWT token | Returns 401 if invalid credentials or inactive | `backend/src/index.ts:135`, `auth_screen.dart` |
| 3 | Auth & User | Current User Profile | Retrieves authenticated user profile & active state | JWT in Authorization header | Full User object | Returns 401/404 if token invalid or user deleted | `backend/src/index.ts:155`, `main.dart` |
| 4 | Auth & User | Edit Profile | Updates user's name, phone, profile picture, or FCM token | `name?`, `phone?`, `profilePic?`, `fcmToken?` | Updated User record | Returns 500/400 on DB failure | `backend/src/index.ts:168`, `edit_profile_screen.dart` |
| 5 | Gamification | Player Points & Tiering | Awards 50 points per booking, calculates level (Bronze <500, Silver 500-1499, Gold 1500-4999, Diamond 5000+) | `userId`, `pointsToAdd` | Updated points, tier, matchesPlayed | Silently aborts if user not found | `backend/src/index.ts:27`, `home_screen.dart:200` |
| 6 | Gamification | Global Leaderboard | Lists top 20 players ordered by points descending | None (GET) | Array of players with points, level, matches, avatar | Returns 500 on server error | `backend/src/index.ts:187`, `home_screen.dart:136` |
| 7 | Venues & Discovery | Browse Venues | Lists all active venues with parsed image arrays and courts | Query filters (optional) | Array of Venue objects with courts and bookings | Returns 500 on DB failure | `backend/src/index.ts:202`, `home_screen.dart:776` |
| 8 | Venues & Discovery | Category Filtering | Filter venues by sport/entertainment category | Category chip (All, كرة قدم, بادل, بلايستيشن, تنس, بلياردو, كرة طائرة) | Dynamically filtered venue list in UI | Shows empty state if none match | `home_screen.dart:801` |
| 9 | Venues & Discovery | Venue Search | Search venues in real-time by name or sport type | Text query | Filtered venue card list | Displays empty message if no matches | `home_screen.dart:781` |
| 10 | Venues & Discovery | Distance Estimation | Shows estimated distance to venue from user in km | Venue location coordinates | Formatted string (e.g. '2.4 كم') | Falls back gracefully | `home_screen.dart:870` |
| 11 | Venues & Discovery | Interactive Map View | Displays all venues as interactive glowing markers on OpenStreetMap | Venue coordinates | Interactive map with marker cards pushing to `/venue/:id` | Skips venues with non-coordinate location strings | `map_screen.dart`, `mobile-app/lib/screens/map_screen.dart` |
| 12 | Venues & Discovery | Venue Details Screen | Displays venue photo carousel, address, open/close hours, amenities, and courts | `venueId` | Venue details, court cards with starting prices | Shows error banner on fetch failure | `venue_details_screen.dart` |
| 13 | Venues & Discovery | Open in Maps | Launches external Google Maps navigation for venue | `location` or `googleMapsLink` | Launches external map app | Shows SnackBar if URL cannot be launched | `venue_details_screen.dart:76` |
| 14 | Court & Booking | Multi-Room / Multi-Court Hierarchy | Each venue contains one or more courts or rooms with specific pricing & amenities | `venueId`, `courtId` | Court model with category-specific options | Cascades delete if venue deleted | `schema.prisma:56`, `venue_details_screen.dart:116` |
| 15 | Court & Booking | Slot Availability Calculator | Generates 30-min booking slots between venue openTime and closeTime, accounting for past times and booked slots | `courtId`, `selectedDate` | List of time slots marked `isBooked: bool` | Filters out rejected/cancelled bookings | `court_booking_screen.dart:33` |
| 16 | Court & Booking | Overnight Venue Hours | Handles venues operating past midnight (e.g. 14:00 to 02:00) | `openTime`, `closeTime` strings | Proper multi-day slot calculation | Handles modulo 24 and next-day indexing | `court_booking_screen.dart:42,94` |
| 17 | Court & Booking | Anti-Double Booking Lock | Checks existing overlapping bookings in status CONFIRMED, PENDING, or ATTENDANCE_CONFIRMED | `courtId`, `startTime`, `endTime` | Rejects booking if overlap found | Returns 400 with "هذا الموعد محجوز مسبقاً" | `backend/src/index.ts:361` |
| 18 | Court & Booking | Booking Financial Math | Computes total price, 5% platform fee, and 95% owner payout | `pricePerHour`, `durationHours` | `price`, `platformFee`, `ownerAmount` | Returns 400 if invalid duration | `backend/src/index.ts:376` |
| 19 | Court & Booking | Booking Creation | Creates booking record in `CONFIRMED` / `PENDING` state, awards 50 points, triggers owner FCM | `courtId`, `startTime`, `endTime`, `isManual?` | Booking object | Returns 400 on collision, 404 if court missing | `backend/src/index.ts:355` |
| 20 | Court & Booking | Player Bookings History | Retrieves user's bookings with pitch/court details and status badges | Authenticated player token | Array of user bookings sorted desc by startTime | Returns empty list if no bookings | `backend/src/index.ts:413`, `home_screen.dart:284` |
| 21 | Court & Booking | Booking Cancellation | Allows player to cancel future bookings | `bookingId`, status: 'CANCELLED' | Updated booking, triggers owner notification | Denied if already cancelled or past | `home_screen.dart:358`, `backend/src/index.ts:517` |
| 22 | Court & Booking | Attendance Confirmation | Player confirms arrival at venue within +/- 1 hour of match start | `bookingId` | Status updated to `ATTENDANCE_CONFIRMED`, notifies owner | Returns 404 if booking not found | `backend/src/index.ts:570`, `home_screen.dart:390` |
| 23 | Court & Booking | Attendance Reminder Cron | Runs every 30 minutes, checks confirmed bookings starting in 1-2 hours, creates alert | System timer | Dispatches push and in-app notifications | Logs error without crashing | `backend/src/index.ts:613` |
| 24 | Reviews | Venue Review Gate | Players can review venue only after confirmed booking | `venueId`, `rating` (1-5), `comment` | Created review, updates venue avg rating and totalReviews | Returns 500 on failure | `backend/src/index.ts:254`, `spotaia_specs.txt:63` |
| 25 | Community | Match Requests Feed | Feed of games seeking extra players to split venue costs | None (GET) | Open match requests with missing spots and cost per spot | Returns empty state if none | `backend/src/index.ts:435`, `home_screen.dart:651` |
| 26 | Community | Create Match Request | Post a game looking for missing players | `title`, `description`, `matchTime`, `missingSpots`, `costPerSpot` | Created MatchRequest record | Returns 400 on invalid input | `backend/src/index.ts:448`, `add_match_request_screen.dart` |
| 27 | Community | Share Match to Social | Shares formatted invite message with missing spots and cost via WhatsApp/ShareSheet | Match details | Native OS share sheet | Graceful error if share fails | `home_screen.dart:751` |
| 28 | Community | Match Chat Room | Real-time group chat for players of a match request | `matchId`, `content`, `senderId` | Polled message history, optimistic UI bubble | Fails because API endpoint is missing | `chat_screen.dart:41,75` |
| 29 | Owner Dashboard | Owner Venue Management | View owned venues, manage venues, and view court count | Owner auth token | List of owned venues with management links | Shows empty message if no venues | `owner_dashboard_screen.dart:180` |
| 30 | Owner Dashboard | Add New Venue | Create venue with location picker, hours, category, and images | Multi-part form, GPS coords, times | Created Venue record | Shows error snackbar on failure | `add_venue_screen.dart` |
| 31 | Owner Dashboard | Interactive Location Picker | Pinpoint venue coordinates on OpenStreetMap | Map tap position | `LatLng` coordinates | Closes without returning if cancelled | `location_picker_screen.dart` |
| 32 | Owner Dashboard | Add/Edit Court | Configure room/court with category-tailored amenities (PS console, football size, AC) | `name`, `pricePerHour`, `amenities` JSON, photos | Court record | Validates required name and price | `add_court_screen.dart` |
| 33 | Owner Dashboard | Court Schedule Timeline | Daily timeline view of all 30-min slots for a court (Booked vs Available) | Date selector | Visual list with status color coding | Handles past midnight correctly | `court_schedule_screen.dart` |
| 34 | Owner Dashboard | Delete Court | Permanently remove court and its associated bookings | `courtId` | Deletes bookings and court | Confirmation dialog required | `manage_venue_screen.dart:79` |
| 35 | Owner Dashboard | Accept/Reject Booking | Owner accepts pending booking or rejects with reason | `bookingId`, `status` ('CONFIRMED' / 'REJECTED') | Updated booking, triggers player push notification | Returns 404 if booking not found | `backend/src/index.ts:517`, `owner_dashboard_screen.dart:101` |
| 36 | Admin | Platform Analytics Stats | Overview of total users, total venues, total bookings, total platform fees | Admin token | `{ totalUsers, totalVenues, totalBookings, totalRevenue }` | 403 Forbidden for non-admins | `backend/src/index.ts:460`, `admin_dashboard_screen.dart:78` |
| 37 | Admin | User Management & Audit | View all users with booking logs, owner venues, and account status | Admin token | Full user list with nested relations | 403 Forbidden for non-admins | `backend/src/index.ts:477`, `admin_dashboard_screen.dart:130` |
| 38 | Notifications | In-App Notification Center | View notification inbox with type icons and dates | User token | List of user notifications | Shows empty inbox if none | `notifications_screen.dart`, `backend/src/index.ts:503` |
| 39 | Notifications | Mark Notifications Read | Mark all unread notifications as read | User token | Success confirmation | Currently fails (missing API endpoint) | `notifications_screen.dart:21` |
| 40 | File Upload | Multipart Image Upload | Upload up to 5 venue/court/profile images to `/uploads` | `multipart/form-data` with images array | `{ urls: string[] }` | Returns 400 if no files uploaded | `backend/src/index.ts:101` |

---

## Edge Cases

| # | Feature | Input | Observed Behavior |
|---|---------|-------|-------------------|
| 1 | Slot Generation | Venue with closing time at 02:00 AM (past midnight) | System adds 24 hours to `closeTime` (`closeHour += 24`) and sets `isNextDay = true` for hours < openTime. |
| 2 | Double Booking | Two users submit booking for overlapping slot simultaneously | Pessimistic conflict check catches overlap; first writer succeeds, second receives `هذا الموعد محجوز مسبقاً` (HTTP 400). |
| 3 | Past Slots | User selects today's date at 18:00 when current time is 18:30 | Slot generator verifies `slotStart.isBefore(DateTime.now())` and skips past time slots. |
| 4 | Map Markers | Venue with non-GPS location string (e.g. "مدينة نصر، القاهرة") | `MapScreen` splits string on comma and tests `double.tryParse`; skips rendering invalid coordinates without crashing. |
| 5 | External Maps | Venue with Google Maps link vs raw GPS coordinates | `VenueDetailsScreen` checks `googleMapsLink`; if present, launches directly, otherwise falls back to `https://www.google.com/maps/search/?api=1&query=$loc`. |
| 6 | Attendance Button | Booking startTime is 3 hours in the future | Button remains hidden. Only appears when `diff <= 1 && diff >= -1` hours from match start. |
| 7 | Booking Cancellation | User attempts to cancel an already completed or rejected booking | UI hides cancellation button if `status == 'CANCELLED'` or `status == 'REJECTED'` or if `startTime` is in the past. |
| 8 | Image Fallback | Court or venue has empty or broken image URL | `CachedNetworkImage` displays Shimmer loading and falls back to dark placeholder with sport icon. |
| 9 | Authentication Session | App restarted after token expiration or invalidation | `SplashScreen` calls `/auth/me`; on failure, catches exception and redirects user to `/auth`. |
| 10 | Onboarding Flag | App launched for the first time | `SplashScreen` checks `hasSeenOnboarding` in SharedPreferences; if false, redirects to `/onboarding`. |
| 11 | Role Routing | User logs in as `ADMIN` vs `OWNER` vs `PLAYER` | `HomeOrOwnerWrapper` switches root view to `AdminDashboardScreen`, `OwnerDashboardScreen`, or `HomeScreen`. |
| 12 | Community Chat | User opens chat room for match request | Frontend calls `/matches/:id/messages` which returns 404; chat displays endless loading shimmer or empty error. |
| 13 | Push Notifications | Device has not granted FCM push permission | `home_screen.dart` wraps `messaging.requestPermission()` in try/catch; fails silently without blocking user experience. |
| 14 | Amenity Sanitization | Owner switches category from Football to PlayStation | `AddCourtScreen` filters amenities before serializing to JSON to prevent football attributes appearing in gaming rooms. |

---

# Requirements Grouping

### 1. Backend Requirements & API Specifications
1. **Fix Missing Endpoints**:
   - `PATCH /api/notifications/read-all`: Mark all notifications for `req.user.userId` as `isRead = true`.
   - `GET /api/matches/:id/messages`: Retrieve chat messages for a match request, sorted by `createdAt` ascending, with sender profile info.
   - `POST /api/matches/:id/messages`: Create a new message for a match request.
   - `GET /api/venues/:id/leaderboard`: Return top attendees or points leaders for a specific venue (or provide graceful mock/empty array).
2. **Type Safety & Compilation**:
   - Resolve any type conflicts under `backend/src/index.ts` and remove `// @ts-nocheck` to guarantee clean `npx tsc --noEmit`.
3. **Database Consistency**:
   - Support PostgreSQL migration path (`prisma migrate deploy`) for cloud deployments (Neon DB).

### 2. Flutter Mobile App Screens, Navigation & UI/UX
1. **Zero-Warning Static Analysis**:
   - Replace deprecated `.withOpacity(x)` with `.withValues(alpha: x)` across all screens.
   - Upgrade deprecated `Share.share` to `SharePlus.instance.share` or standard `SharePlus` API.
   - Remove unused imports (`url_launcher`, `dio`, `image_picker`, `dart:typed_data`).
   - Remove unused local variables (`isUnpaid`, `user`).
   - Add `if (!mounted) return;` guards before all `BuildContext` uses across async gaps.
   - Add `const` keywords to constructors and literal lists.
2. **Centralized API & URL Management**:
   - Remove hardcoded `http://192.168.1.10:3001` in `getFullUrl()` across `home_screen.dart`, `venue_details_screen.dart`, `court_booking_screen.dart`, `owner_dashboard_screen.dart`, `admin_dashboard_screen.dart`, and `edit_profile_screen.dart`.
   - Route all media and API endpoints through `kProductionApiUrl` in `api_provider.dart`.
3. **Theme & Branding Polish**:
   - Maintain the Dark Neon aesthetic (`#0A0A0A`, `#121212`, `#00E5FF`, `#FF9100`).
   - Ensure RTL Cairo typography renders cleanly on all device densities.

### 3. State Management, Offline Behavior, Error Boundaries & Caching
1. **Global Error Boundaries**:
   - Ensure all Dio network calls present friendly Arabic error messages via `SnackBar` or error placeholders rather than raw exception strings.
2. **Offline & Connectivity Detection**:
   - Add connectivity checks with user feedback if the backend server is unreachable.
3. **Cache Policy**:
   - Image caching via `cached_network_image`.
   - Provider invalidation synchronization on every state mutation (booking, cancellation, review, court edit).

### 4. Testing, Analysis & Release APK Build Criteria
1. **Static Analysis**:
   - `flutter analyze` must pass with zero issues.
2. **Backend Build**:
   - `npx tsc --noEmit` must pass with zero errors.
3. **Widget & Unit Tests**:
   - Replace template `widget_test.dart` with valid Spotaia smoke tests verifying that `SpotaiaApp` initializes, builds the router, and renders without unhandled exceptions.
4. **Android Release APK Build**:
   - Run `flutter build apk --release` targeting Java 17 (`jdk17/jdk-17.0.12+7`).
   - Ensure `AndroidManifest.xml` includes `android:usesCleartextTraffic="true"` for local HTTP testing.
   - Verify output APK artifact is generated in `build/app/outputs/flutter-apk/app-release.apk`.
