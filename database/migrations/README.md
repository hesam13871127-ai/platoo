# Database migrations

`../schema.sql` is the idempotent initial MySQL 8 migration used by the container and by `npm run db:migrate`. Future migrations should be added as numbered SQL files and applied by the deployment migration job before rolling out the API.
