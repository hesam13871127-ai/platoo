# VibeTable architecture

## Request flow

Flutter uses `ApiClient` for `/api/v1` REST calls and attaches the access JWT from `flutter_secure_storage`. The refresh interceptor rotates a refresh session when an access token expires. Match and chat updates are delivered over Socket.IO using the same JWT in the handshake.

Nest modules are intentionally vertical:

- `auth` owns OTP/social identity verification and refresh sessions.
- `users` owns profiles, friends, groups, and reports.
- `wallet` owns the double-entry-like balance ledger, shop inventory, purchases, and gifts.
- `chat` owns conversation membership and message history; the gateway only transports validated service calls.
- `games` owns the registry, authoritative engines, match revisions, replays, private-state filtering, and game gateway.
- `matchmaking` owns tickets and the 15-second bot fallback.
- `ranking` owns seasons, Elo, stats, and rewards.
- `admin` owns audited operations and moderation.

## State authority

A game engine receives a JSON state, player roster, actor, and action. It validates turn ownership and rule legality, returns a new state, and reports winners/draws. The game service takes a row lock on the match, persists the next revision and action replay, then broadcasts a viewer-filtered snapshot. Hidden cards, fleets, roles, and memory values are filtered per viewer before transport.

## Match integrity

Turn clocks are authoritative on the server and derived from `matches.updated_at`, so no schema change was needed: `GameRegistry.turnSeconds(gameId, state)` returns the per-move budget (30s for instant games such as `four_in_a_row`/`darts`/`bowling`/`word_chain`, 45s for `ludo`/`mancala`/`dominoes`/`hearts`/`spades`/`mini_golf`, 60s default, 90s `werewolf`, 120s `sketch_guess` drawing / 30s guessing, 180s `chess`). Match payloads carry `turnSeconds`, an absolute `turnDeadline`, and `serverTime` so clients render a skew-corrected countdown.

Enforcement is a 10-second `@Interval` sweeper in `GameService`:

- Past-deadline bot turns re-trigger the existing bot loop (crash recovery).
- Past-deadline human turns are auto-played through the normal `act()` path using the engine's `botAction` for that player, recording an `_idleStrikes` counter inside the match state (stripped before transport, cleared when the human acts).
- A third consecutive strike in a `ranked` match forfeits: the idle player takes a loss and the opponents win.
- Matches idle over 15 minutes are `cancelled` (results stay `pending`, no rating change, audit row in `match_events`); `sea_battle` matches stuck in `placing` over 10 minutes are cancelled the same way.

Players can leave cleanly via `POST /matches/:id/resign` (or the `game:resign` socket event): the resigner takes a loss, remaining humans win, and a solo player resigning against bots hands the bots the win. Resignations settle through the standard ranking/rewards path and appear in replays as `resign` moves.

Related engine repairs: `word_chain` ends after `players × 8` words with unique bot words, `hearts` awards the lowest score with even three-player deals, `archery` gives every player five shots, `bowling` bots roll legal pin counts and every player completes the tenth frame, `darts` bots never bust, and `backgammon` supports `pass`, both-sided bar re-entry, and a bot that passes only when no legal move exists.

## Scaling path

The current queue scheduler is safe for one API instance and persists tickets in MySQL. For multi-instance deployment, run one scheduler worker (or move the `processQueue` lock to Redis with a distributed lock) while Socket.IO should use the standard Redis adapter. MySQL remains the source of truth for wallet and match revisions.

## Admin panel

The `admin` module exposes audited operations under `/api/v1/admin`. Every mutation writes a row to `admin_audit_log` (queryable via `GET /admin/audit-log`).

### Access control

- All routes require a JWT for an `active` user plus `moderator` or `admin` role (`JwtAuthGuard` + `RolesGuard`).
- Admins inherit moderator privileges. Mutations that change money, access, catalog, or seasons are `@Roles('admin')` and return `403` for moderators.
- Safety rails: self-ban/self-suspend and self-role-changes are rejected, admin accounts cannot be banned or suspended, and the last active admin cannot be demoted. Banning/suspending revokes all refresh sessions and notifies the user.
- The Flutter console (`AdminScreen`, reachable from the login screen's **Admin / staff entry** in development) is hidden for non-staff roles and re-checks the role before rendering; admin-only actions are hidden for moderators.
- Local development can use `POST /api/v1/auth/dev-admin` with the configured `DEV_ADMIN_USERNAME` and `DEV_ADMIN_PASSWORD` while `DEV_ADMIN_ENABLED=true` and `NODE_ENV` is not `production`. The default credentials are `admin` / `vibetable-admin`; the API creates only a new active admin account or accepts an already-active admin/moderator account, and never promotes a normal player automatically.

### Endpoint reference (all under `/api/v1/admin`)

| Area | Endpoints |
|---|---|
| Dashboard | `GET /overview`, `GET /analytics?days=7..90`, `GET /matches/recent?limit=`, `GET /audit-log?page=&limit=&action=&adminId=` |
| Users (moderators read, admins write) | `GET /users?q=&status=&role=&page=&limit=`, `GET /users/:id`, `PATCH /users/:id` (admin), `POST /users/:id/ban` (admin), `POST /users/:id/unban` (admin), `POST /users/:id/wallet` (admin, `{coins, pips, reason}`) |
| Shop | `GET /shop`, `POST /shop` (admin), `PATCH /shop/:id` (admin, full edit incl. `isActive`), `DELETE /shop/:id?hard=` (admin; soft-deactivates when players own the item) |
| Games | `GET /games`, `PATCH /games/:id` (admin, incl. `isActive` toggle) |
| Reports | `GET /reports?status=&category=&reportedUserId=&page=&limit=`, `GET /reports/:id`, `PATCH /reports/:id` (`{status, resolutionNote, moderationAction: none\|warn\|suspend_reported}`; suspend requires admin) |
| Seasons | `GET /seasons`, `POST /seasons` (admin), `GET /seasons/:id`, `PATCH /seasons/:id` (admin), `DELETE /seasons/:id` (admin, scheduled only), `POST /seasons/:id/activate` (admin), `POST /seasons/:id/finish` (admin, pays rewards), `GET/POST /seasons/:id/rewards` (POST admin), `DELETE /seasons/:id/rewards/:rewardId` (admin) |

List endpoints that support paging return `{items, page, limit, total, totalPages}`.

### Bootstrapping the first admin

There is no public sign-up for staff roles. Promote an existing user directly in MySQL:

```sql
UPDATE users SET role = 'admin' WHERE username = 'your_username';
```
