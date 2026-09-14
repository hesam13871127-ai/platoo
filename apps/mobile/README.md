# VibeTable mobile client

Flutter 3.24+ client for the VibeTable API. The application uses Riverpod for state, Dio for REST, Socket.IO for live match updates, LiveKit for voice rooms, and secure storage for rotating JWT sessions.

## First-time setup

The repo ships only the Dart code — generate the native shells once (preserves `lib/` and `pubspec.yaml`):

```bash
flutter create --platforms=android,ios .
flutter pub get
```

Android local testing needs one manifest tweak (emulator/device IPs are not exempt from cleartext rules): set `android:usesCleartextTraffic="true"` on `<application>` in `android/app/src/main/AndroidManifest.xml`. Never ship that to production — serve the API over HTTPS instead.

## Run

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1   # Android emulator (also the default)
flutter run --dart-define=API_URL=http://127.0.0.1:3000/api/v1  # iOS simulator
flutter run --dart-define=API_URL=http://<lan-ip>:3000/api/v1    # physical device
```

For a device use the API host reachable from the device (same Wi-Fi/LAN, firewall open on 3000). Browser-facing code must never hardcode hosts: deploy the API behind the same public host or pass its reachable URL with `API_URL`.

The phone flow expects E.164 numbers. Development deployments can set `DEV_OTP_ENABLED=true`; the API response exposes the generated code only in that mode. Google and Apple require their platform client configuration and a matching `GOOGLE_CLIENT_ID` or Apple bundle ID on the API.
