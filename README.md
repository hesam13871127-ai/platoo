# VibeTable

VibeTable is a real-time social tabletop platform: fast games, friends, voice rooms, chat, cosmetics, seasonal ranks, and a moderator console in one consistent product.

## Repository layout

- `apps/api` — NestJS 10 API and Socket.IO namespaces (`/chat` and `/games`).
- `apps/mobile` — Flutter 3.24+ client with Riverpod 2, English/Persian RTL, light/dark themes, game boards, shop, social, chat, and admin views.
- `packages/contracts` — shared game, match, wallet, and session contracts.
- `database/schema.sql` — MySQL 8 schema with ledger, inventory, friendship, group, chat, match replay, season, ranking, moderation, and LiveKit room tables.
- `database/seed.sql` — all 28 game catalog records, starter shop catalog, and the active 2026 season.

## Local development

1. Install Node.js 20.11+ and Flutter 3.24+.
2. Copy `.env.example` to `apps/api/.env` or export the values from the repository root.
3. Start infrastructure:

   ```bash
   docker compose up -d mysql redis
   ```

4. Install and build the API:

   ```bash
   npm install
   npm run build
   npm run db:migrate
   npm run db:seed
   npm run dev:api
   ```

5. Run the client:

   ```bash
   cd apps/mobile
   flutter pub get
   flutter run --dart-define=API_URL=http://10.0.2.2:3000/api/v1
   ```

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
