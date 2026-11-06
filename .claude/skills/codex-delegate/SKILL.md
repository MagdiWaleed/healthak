---
name: codex-delegate
description: Delegate a bounded implementation phase to the Codex CLI (`codex exec`), then review and verify its diff. Use when the user wants Claude as planner/reviewer and Codex as the coder, or says "use codex".
---

# Codex delegate

Claude is the brain: spec, review, verify. Codex writes the code.

## 1. Spec
Write `<scratchpad>/specN.md`:
- Goal (one paragraph) and acceptance criteria.
- Files to create/modify, and existing files/functions to reuse (with paths).
- Hard constraints from AGENTS.md (pure-Dart domain, Arabic strings in
  `lib/l10n/app_strings.dart`, no `print`, glass blur budget, no Gradle changes,
  no `google_sign_in`, never touch `ai_secrets.json` or service-account keys).
- "Run `flutter analyze --no-pub` and `flutter test --no-pub` before finishing.
  Do not commit. End with a summary of files changed and any open issues."

## 2. Run
```bash
codex exec -C <repo> -s workspace-write -o <scratchpad>/specN-result.md - < <scratchpad>/specN.md
```
Run in background for long phases. Codex sandbox may block network; run
`flutter pub get` yourself first if pubspec changed.

## 3. Review
- `git status` + `git diff` — read every hunk. Check architecture rules,
  correctness, RTL, tests actually assert behavior.
- Run analyze + tests yourself. Never trust the result file alone.

## 4. Iterate
```bash
codex exec resume --last -C <repo> -s workspace-write "Fix: <numbered findings>"
```
Hand-edit only small corrections. Commit per phase after the CLI app gate
(build APK, adb install, drive, screencap, logcat).

## CLI app gate (required every phase)
```bash
bash tool/cli_smoke.sh <phase-tag> --build [--define-file ai_secrets.json] "<tab label>" "<button label>" ...
```
Taps by accessibility label, screenshots each step to `output/emulator-ux/`, fails on
Flutter errors in logcat. Read the screenshots — PASS alone does not prove the UI looks right.
