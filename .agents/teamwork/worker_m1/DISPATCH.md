## 2026-09-25T08:14:31Z
You are the Implementation Worker for Milestone 1 (Backend Production Refactoring & Type Safety).
Working directory: c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\worker_m1\

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY: Read the original user request at:
c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\ORIGINAL_REQUEST.md

Read the project scope and comprehensive Explorer handoff reports:
- c:\Users\MoBadawy\Desktop\New folder\PROJECT.md
- c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\explorer_m1_1\handoff.md
- c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\explorer_m1_2\handoff.md
- c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\explorer_m1_3\handoff.md
- c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\explorer_m1_1\proposed_index.ts (if useful reference)
- c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\explorer_m1_1\proposed_tsconfig.json (if useful reference)

EXCLUSIVE WRITE OWNERSHIP:
You own files in `c:\Users\MoBadawy\Desktop\New folder\backend\` exclusively. Do NOT touch any files in `mobile-app/` or outside `backend/`.

YOUR MISSION & TASKS:
1. TypeScript Compilation & Clean tsconfig:
   - Remove `// @ts-nocheck` from `backend/src/index.ts`.
   - Update `backend/tsconfig.json` to exclude `api` and include `src/**/*` and `prisma/**/*`. Remove or archive obsolete `backend/api/`.
   - Fix all 48 TypeScript compiler errors in `backend/src/index.ts`:
     * Fix Line 164 ReferenceError: `console.error(e)`.
     * Narrow Express 5 route parameters (`as string`) so Prisma where clauses and relational properties (`court`, `venue`, `user`, `courts`) typecheck cleanly.
     * Fix Stripe API version typing (`'2026-08-26.dahlia'`).
     * Fix review aggregate calculation (`aggr._count?.id || 0`).
     * Fix PORT typing (`Number(process.env.PORT) || 3001`).
     * Migrate Firebase Admin to modular v14 syntax (`firebase-admin/app`, `firebase-admin/messaging`).
2. Missing Endpoints:
   - Implement `PATCH /api/notifications/read-all` (mark all unread notifications for `req.user.userId` as read).
   - Implement `GET /api/matches/:id/messages` (return messages sorted by `createdAt ASC` with sender profile info) and `POST /api/matches/:id/messages` (validate content, verify match, attach senderId).
   - Implement `POST /api/admin/users/:id/toggle-ban` (toggle `isActive` with admin authorization and self-ban protection).
   - Implement `DELETE /api/admin/venues/:id` and `DELETE /api/admin/pitches/:id` (atomic cascade deletion).
   - Implement `GET /api/venues/:id/leaderboard` (return top attendees/points leaders for venue).
3. Security, Concurrency & Error Handling:
   - Atomic double-booking lock inside Prisma interactive `$transaction` to prevent race conditions.
   - Restrict registration: do NOT allow unauthenticated public callers to create `ADMIN` accounts (force `role: 'PLAYER'` or validate role).
   - Enforce authorization checks on `PATCH /api/bookings/:id/status` (creator, venue owner, or admin) and `POST /api/bookings/:id/confirm-attendance` (creator only).
   - Permit Super Admins (`req.user.role === 'ADMIN'`) to manage/delete courts.
   - Scrub `passwordHash` across all user endpoints.
   - Implement Express global JSON error handler returning `{ error: message }` without raw stack traces or HTML.
4. Verification:
   - Run `npx tsc --noEmit` in `backend/` and verify that it exits with 0 and zero diagnostics.
   - Verify that all endpoints and logic work without runtime crashes.
5. Reporting:
   - Write your complete handoff report to `c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\worker_m1\handoff.md`.
   - Update `progress.md` in your working directory with status and timestamp.
   - Send a completion message to the orchestrator with verbatim `npx tsc --noEmit` verification results.
