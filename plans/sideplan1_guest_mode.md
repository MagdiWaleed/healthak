# Side Plan 1 — Guest Mode

**Goal:** a first-time visitor can open Healthak and see a truthful preview before creating an
account.

**Status:** initial preview complete. Integrate it into the Step 1 named-route shell when that
shell is built.

## Decision

Guest mode is **read-only and local**. It shows representative UI only; it does not create an
anonymous Firebase user, read protected catalog data, write a profile, or weaken Firestore rules.
The current rules intentionally require authentication for `foods`, `users`, and marketplace data.

## Current behaviour

- No saved legacy user opens `GuestPreviewScreen` automatically.
- The screen visualizes the daily target and meal ideas without a network request.
- The only primary action opens the existing sign-in/create-account flow.
- A returning saved user continues to the legacy home unchanged.

## Follow-up when the Step 1 shell exists

- Add a named `/guest` route and make `/splash` choose `/guest`, `/onboarding`, or `/home` from
  the real auth/profile state.
- Keep the guest screen read-only unless authenticated anonymous Firebase access is requested.
- Replace preview numbers with a local demo fixture only if an interactive demo is requested.

## Acceptance checks

- A fresh launch does not show the legacy sign-in form first.
- No unauthenticated Firestore read or write occurs from guest mode.
- The sign-in button remains available and guest mode does not persist user data.

## Verification

Verified on `emulator-5554`: the debug APK installs and launches with no `permission-denied`,
`FirebaseException`, or `cloud_firestore` error in the post-launch log. Startup no longer reads
the blocked legacy `data` collection; the legacy home uses its bundled image instead.
