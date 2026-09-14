# VibeTable

VibeTable is a real-time social tabletop platform: fast games, friends, voice rooms, chat, cosmetics, seasonal ranks, and a moderator console in one consistent product.

## Repository layout

- `apps/api` — NestJS 10 API and Socket.IO namespaces (`/chat` and `/games`).
- `apps/mobile` — Flutter 3.24+ client with Riverpod 2, English/Persian RTL, light/dark themes, game boards, shop, social, chat, and admin views.
- `packages/contracts` — shared game, match, wallet, and session contracts.
- `database/schema.sql` — MySQL 8 schema with ledger, inventory, friendship, group, chat, match replay, season, ranking, moderation, and LiveKit room tables.
- `database/seed.sql` — all 28 game catalog records, starter shop catalog, and the active 2026 season.

## Run it locally

### Prerequisites

- Node.js 20.11+ and Docker with the Compose plugin.
- Flutter 3.24+ with an Android emulator or iOS simulator (Xcode/CocoaPods on macOS for iOS).
- Ports `3000` (API), `3306` (MySQL), `6379` (Redis) free on your machine.

### 1. Configure the API

```bash
cp .env.example apps/api/.env
```

The defaults work out of the box for local development. Every variable is documented with comments in `.env.example`; the only file the API reads automatically is `apps/api/.env` (a root `.env` is ignored unless you export it yourself).

### 2. Start MySQL and Redis

```bash
docker compose up -d mysql redis
```

On first start this creates the database and applies `database/schema.sql` + `database/seed.sql` automatically (28 games, shop catalog, season, bot pool).

### 3. Install, build, migrate, seed, run

```bash
npm run setup     # install + build + migrate + seed (needs step 2 running)
npm run dev:api   # watch-mode API on http://localhost:3000
```

Verify: `curl http://localhost:3000/api/v1/health/ready` should return `{"status":"ready",...}`.

Prefer Docker for the API too? `docker compose up -d --build api` instead of `npm run dev:api`. The container reads its config from `docker-compose.yml`, not from `apps/api/.env`.

### 4. Run the Flutter app

The repo ships the Dart code (`lib/`, `pubspec.yaml`) but **no `android/`/`ios/` folders** — generate them once (this preserves all existing code):

```bash
cd apps/mobile
flutter create --platforms=android,ios .
flutter pub get
```

Then run against your API (pick one target):

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1   # Android emulator
flutter run --dart-define=API_URL=http://127.0.0.1:3000/api/v1  # iOS simulator
flutter run --dart-define=API_URL=http://<your-lan-ip>:3000/api/v1  # physical device
```

Notes:

- The default `API_URL` is the Android-emulator address, so the first command also works without the flag.
- Android blocks plain-HTTP to non-localhost IPs: after `flutter create`, set `android:usesCleartextTraffic="true"` on the `<application>` tag in `android/app/src/main/AndroidManifest.xml` for local testing (never ship that to production — serve the API over HTTPS).
- Sign in with any E.164 phone number (e.g. `+14155552671`); with `DEV_OTP_ENABLED=true` the API response contains the `devCode` to enter.

### 5. Useful commands

```bash
npm test            # backend unit/integration tests (65 tests, no DB needed)
npm run lint        # backend type check
npm run db:migrate  # re-apply schema (safe to re-run)
npm run db:seed     # re-apply seed data (idempotent)
docker compose logs -f api        # follow API logs (Docker setup)
docker compose down -v            # FULL reset: deletes the MySQL volume
```

`docker compose down -v` is the clean-slate button: schema/seed init scripts only run on an empty volume, so use it if your database predates a schema change (then re-run seed via `npm run db:seed` or a fresh `up`).

### Troubleshooting

- **API exits with `ECONNREFUSED 127.0.0.1:3306`** — MySQL isn't up yet; wait for `docker compose ps` to show it healthy, then restart the API.
- **`Refusing to boot with unsafe production config`** — you're running with `NODE_ENV=production`; use `development` locally or set real secrets (see the production checklist below).
- **`flutter run` fails with missing `android/`/`ios`** — you skipped step 4's `flutter create`.
- **App can't reach the API on a physical device** — the device and your machine must share Wi-Fi/LAN, use your machine's LAN IP in `API_URL`, and check the OS firewall on port 3000.
- **Port already in use** — another MySQL/Redis/API is running; stop it or adjust the ports in `docker-compose.yml` / `.env`.

## First Run Checklist

Run these in order; stop at the first failure and check Troubleshooting above.

- [ ] `node --version` ≥ 20.11, `flutter --version` ≥ 3.24, `docker compose version` works.
- [ ] `cp .env.example apps/api/.env` done (or env exported).
- [ ] `docker compose up -d mysql redis` → both report healthy in `docker compose ps`.
- [ ] `npm run setup` completes with "VibeTable schema applied." and "VibeTable seed data applied."
- [ ] `npm run dev:api` boots with "MySQL connection pool ready" and "Shared bot pool ready (12 accounts)".
- [ ] `curl http://localhost:3000/api/v1/health/ready` returns `"status":"ready"`.
- [ ] `npm test` → 4 suites, 65 tests, all passing.
- [ ] `cd apps/mobile && flutter create --platforms=android,ios . && flutter pub get` succeeds.
- [ ] Android only: `usesCleartextTraffic="true"` set in the debug manifest (see step 4).
- [ ] `flutter run` with the right `API_URL` shows the sign-in screen; OTP login works with the `devCode`.
- [ ] In the app: queue for a quick game (bot fills after 15s), play it to the result screen, send one chat message.
- [ ] Optional: promote yourself to admin directly in MySQL (`UPDATE users SET role='admin' ...`) to tour the Admin Panel.

The API is available at `http://localhost:3000/api/v1/health`. In development, `DEV_OTP_ENABLED=true` returns `devCode` from the OTP request response; production must provide an `OTP_WEBHOOK_URL` for an approved SMS provider and set it to false.

## Runtime contracts

- Access tokens are short-lived JWTs. Refresh tokens are rotated, hashed at rest, and revoked on logout.
- MySQL transactions lock wallets, match state, ratings, and OTP challenges before mutation. Shop purchases accept an idempotency key.
- Match state is authoritative on the server. Every action is validated by a dedicated engine and persisted as a revisioned replay event.
- A queued ticket is matched with compatible tickets first. A compatible human-like bot fills the requested table after 15 seconds; bot accounts are never presented as real players.
- `/chat` and `/games` Socket.IO namespaces authenticate the same access JWT. Voice tokens are issued for LiveKit only after match/conversation membership is checked.
- Ranking uses per-game, per-season Elo with K=32, result statistics, peak rating, and season reward payouts.

## Quality checks

```bash
npm run build
npm test
```

The authoritative engine tests cover four-in-a-row wins, chess legality, Mancala turn flow, and Ocho card legality. The application keeps game rules in `apps/api/src/games/engines`, separate from transport and persistence.

## Production readiness checklist

The API refuses to boot with `NODE_ENV=production` unless these hold:

- `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` are unique and at least 32 characters.
- `CORS_ORIGINS` lists the allowed web origins (mobile apps are unaffected).
- `DEV_OTP_ENABLED=false` and `OTP_WEBHOOK_URL` points at the approved SMS provider.

Also recommended before launch: non-default `DB_USER`/`DB_PASSWORD` (or `DATABASE_URL`), Verified LiveKit credentials, and the shop/season seed reviewed in `database/seed.sql`.

## Operations

- Health: `GET /api/v1/health` (liveness, always 200) and `GET /api/v1/health/ready` (readiness, 503 while MySQL is unreachable). Point load-balancer checks at `/ready`.
- Rate limits: per-route fixed windows (auth 5–30/min by IP, chat sends 60/min, game actions 180/min, polling endpoints 300/min), plus per-socket flood guards on `message:send`, `typing`, and `game:action`. Responses carry `X-RateLimit-*` and `Retry-After` headers; `RATE_LIMIT_ENABLED=false` disables them in an emergency.
- Bots: matches share a pool of 12 `bot_*` accounts instead of minting a `users` row per bot per match. Fresh databases get the pool from `database/seed.sql`; older databases self-heal at startup (`users.is_bot` is added automatically when DDL is permitted). To add the column manually: `ALTER TABLE users ADD COLUMN is_bot TINYINT(1) NOT NULL DEFAULT 0, ADD KEY idx_users_bot (is_bot);`
- Errors: every failure returns `{ error: { code, message, requestId? } }` with an `x-request-id` header for log correlation — include it in bug reports.
- Existing databases pick up schema changes by re-running `npm run db:migrate` (wholesale `CREATE TABLE IF NOT EXISTS` plus the self-healing `ALTER`s above); `npm run db:seed` is idempotent.
