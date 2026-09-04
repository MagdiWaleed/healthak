# diet_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## AI assistant (Grok) setup

Chat feature calls xAI directly from the Flutter client — no Cloud Functions deploy, no Blaze plan needed.

1. Get key at console.x.ai. Set spend cap: Billing → Spending limits (or use prepaid credits). Make a dedicated key for this app.
2. Copy `ai_secrets.example.json` to `ai_secrets.json` (gitignored, never commit it). Fill in `XAI_API_KEY`.
3. Run with the key baked in:
   ```bash
   flutter run -d emulator-5554 --dart-define-from-file=ai_secrets.json
   ```
4. Same flag needed for release builds:
   ```bash
   flutter build apk --dart-define-from-file=ai_secrets.json
   ```

Default model is `grok-3-mini` (cheapest). Change via the model chip in the assistant tab header, or override the default with `XAI_MODEL` in `ai_secrets.json`.

Never paste the raw key into chat, commits, or logs.
