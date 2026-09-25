## 2026-09-25T08:06:14Z

You are Explorer 2 for Milestone 1 (Backend Production Refactoring & Type Safety).
Working directory: c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\explorer_m1_2\

MANDATORY: Read the original user request at:
c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\ORIGINAL_REQUEST.md

Read the project scope and survey artifacts:
- c:\Users\MoBadawy\Desktop\New folder\PROJECT.md
- c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\explorer_backend_survey\handoff.md
- c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\spec_miner_survey\handoff.md
- c:\Users\MoBadawy\Desktop\New folder\backend\src\index.ts
- c:\Users\MoBadawy\Desktop\New folder\backend\prisma\schema.prisma

Your focus: Missing Endpoints & Route Parity Strategy
1. Formulate the exact implementation and TypeScript code for the 5 missing endpoints called by the mobile app and dashboard:
   - `PATCH /api/notifications/read-all`: Mark all notifications for `req.user.userId` as read (`isRead: true`).
   - `GET /api/matches/:id/messages`: Return messages for match request sorted by `createdAt ASC`, including sender profile info.
   - `POST /api/matches/:id/messages`: Create a message for a match request, validating sender and content.
   - `POST /api/admin/users/:id/toggle-ban`: Toggle `isActive` status of a user (admin only).
   - `DELETE /api/admin/venues/:id` and `DELETE /api/admin/pitches/:id`: Cascade delete a venue and its courts/bookings (admin only).
   - `GET /api/venues/:id/leaderboard`: Return top attendees/points leaders for the venue.
2. Verify all models exist in `schema.prisma` (`Notification`, `MatchRequest`, `Message`, `Venue`, `User`) and specify exact Prisma query syntax.
3. Formulate a concrete, step-by-step implementation recipe for the Worker.
4. Write your findings to `c:\Users\MoBadawy\Desktop\New folder\.agents\teamwork\explorer_m1_2\handoff.md`.
5. Update `progress.md` in your working directory with status and timestamp.
6. Send a completion message to the orchestrator.
