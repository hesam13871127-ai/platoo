# VibeTable mobile client

Flutter 3.24+ client for the VibeTable API. The application uses Riverpod for state, Dio for REST, Socket.IO for live match updates, LiveKit for voice rooms, and secure storage for rotating JWT sessions.

## Run

```bash
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1
```

For iOS Simulator use `http://127.0.0.1:3000/api/v1`; for a device use the API host reachable from the device. The API never appears as `localhost` in browser-facing code: deploy the API behind the same public host or pass its reachable URL with `API_URL`.

The phone flow expects E.164 numbers. Development deployments can set `DEV_OTP_ENABLED=true`; the API response exposes the generated code only in that mode. Google and Apple require their platform client configuration and a matching `GOOGLE_CLIENT_ID` or Apple bundle ID on the API.
