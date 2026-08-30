# flutter_homeassistant

A Flutter dashboard that connects to Home Assistant over its WebSocket API
and shows live entity states, grouped by domain, with basic controls
(lights/switches/fans, locks, covers, climate). Built for a portrait
wall-mounted panel (Raspberry Pi + 12.3" 720x1920 DSI screen, driven by
[flutter-pi](https://github.com/ardera/flutter-pi)).

## Architecture

- `lib/src/ha_client/` — the WebSocket protocol client (`ha_websocket_client.dart`):
  auth handshake, `get_states`, `subscribe_events`, `call_service`, all
  correlated by message id. `ha_credentials_store.dart` persists the base URL
  and long-lived access token as a plain JSON file (see note below on why
  not `flutter_secure_storage`).
- `lib/src/providers/` — Riverpod providers wiring the client into the UI:
  `entitiesProvider` connects, does the initial `get_states`, then keeps a
  live `Map<entityId, HaEntity>` updated from the `state_changed` subscription.
- `lib/src/features/onboarding/` — first-run screen to enter the HA URL and
  a long-lived access token (generate one from your HA user profile page).
- `lib/src/features/dashboard/` — the entity grid, grouped by domain, with
  per-domain card widgets.

## Running it during development

```
flutter run -d macos   # or chrome, linux, etc — anything you have set up
```

You'll need a Home Assistant long-lived access token: HA → your profile →
scroll to "Long-Lived Access Tokens" → Create Token.

## Deploying to the Raspberry Pi (flutter-pi)

flutter-pi renders straight to the framebuffer via DRM/KMS — no X11/Wayland
desktop required, which suits a dedicated kiosk panel. It does **not** use
Flutter's official `linux/` desktop embedder (the `linux/` folder in this
repo is just the standard `flutter create` output, harmless to keep for
desktop testing but unused on the Pi).

High-level steps (see the [flutter-pi README](https://github.com/ardera/flutter-pi)
for full detail, since exact steps vary by Pi model/OS image):

1. On the Pi: build/install `flutter-pi` itself (a small C project; the
   flutter-pi repo has Raspberry Pi build instructions).
2. Build the app bundle for arm/arm64 using
   [`flutterpi_tool`](https://pub.dev/packages/flutterpi_tool) (maintained by
   the flutter-pi author, and the recommended way to produce a build that
   matches flutter-pi's engine):
   ```
   dart pub global activate flutterpi_tool
   flutterpi_tool build --arch=arm64 --cpu=pi4   # adjust flags for your Pi model
   ```
3. Copy the resulting `build/flutter_assets` bundle to the Pi and run it:
   ```
   flutter-pi --release /path/to/flutter_assets
   ```
4. For kiosk boot, run flutter-pi from a systemd unit / autologin shell
   profile rather than a desktop session.

Cross-compiling for arm64 Linux isn't supported from a macOS host, so step 2
generally needs to run either on the Pi itself or on a Linux build machine/CI.

### Why `shared_preferences` instead of `flutter_secure_storage`

The secure-storage Linux backend depends on a D-Bus secret-service daemon
(gnome-keyring, kwallet, ...), which a headless Raspberry Pi OS Lite kiosk
image typically doesn't run, and it has no web implementation at all. Since
this is meant to be a single-user, physically-secured wall panel — and is
also previewed in a browser during development — `HaCredentialsStore` just
uses plain `shared_preferences`, which has a working implementation on every
target this app runs on.
