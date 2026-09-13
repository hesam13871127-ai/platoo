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

## Scaling path

The current queue scheduler is safe for one API instance and persists tickets in MySQL. For multi-instance deployment, run one scheduler worker (or move the `processQueue` lock to Redis with a distributed lock) while Socket.IO should use the standard Redis adapter. MySQL remains the source of truth for wallet and match revisions.
