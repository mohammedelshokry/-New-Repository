# Original User Request

## 2026-09-25T07:50:02Z

# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview
> Requested team: Full autonomous team

Perform a full, end-to-end audit, UX/UI enhancement, rigorous testing, and production-grade refactoring of the Spotaia Flutter app and Node.js backend before building the final release APK.

Working directory: c:\Users\MoBadawy\Desktop\New folder
Integrity mode: demo

## Requirements

### R1. Comprehensive Code & Architecture Audit (Phase 1)
Analyze the complete Flutter and Node.js codebase. Fix syntax errors, logical bugs, state edge-cases, and memory leaks. Refactor code for DRY principles and modularity. Optimize load times.

### R2. UX/UI & Feature Enhancement (Phase 2)
Implement smooth UI navigation, transitions, state persistence, error boundaries, and empty-state handling across all screens. Align with industry-leading standards.

### R3. Rigorous Testing & Self-Debugging (Phase 3)
Run static code analysis (`flutter analyze`, `tsc`). Simulate offline modes and network failures. Independently fix discovered bugs.

### R4. Pre-Release Verification (Phase 4)
Verify all configurations, state management, routing, and APIs operate without unhandled exceptions. Generate a summary report of changes.

## Acceptance Criteria

### Verification
- [ ] `flutter analyze` returns zero issues.
- [ ] Backend compiles without errors using `npx tsc --noEmit`.
- [ ] The app successfully builds a release APK (`flutter build apk --release`) without compilation errors.
- [ ] All API errors are cleanly caught and presented to the user without raw exceptions.
- [ ] A final Markdown report is produced detailing all bugs fixed and features enhanced.
