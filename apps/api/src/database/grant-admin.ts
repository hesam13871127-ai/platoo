import 'reflect-metadata';
import mysql from 'mysql2/promise';
import configuration from '../config/configuration';

/**
 * Bootstraps staff access: `npm run admin:grant -- <username|email|id> [role]`.
 * Roles are validated against the users enum and default to `admin`.
 */
async function grant(): Promise<void> {
  const [identifier, role = 'admin'] = process.argv.slice(2);
  if (!identifier) {
    console.error('Usage: npm run admin:grant -- <username|email|user-id> [player|moderator|admin]');
    process.exitCode = 1;
    return;
  }
  if (!['player', 'moderator', 'admin'].includes(role)) {
    console.error(`Unknown role "${role}". Use player, moderator or admin.`);
    process.exitCode = 1;
    return;
  }
  const config = configuration();
  const connection = await mysql.createConnection({
    host: config.database.host,
    port: config.database.port,
    user: config.database.user,
    password: config.database.password,
    database: config.database.name,
  });
  try {
    const [result] = await connection.execute<mysql.ResultSetHeader>(
      `UPDATE users SET role = ? WHERE username = ? OR email = ? OR id = ?`,
      [role, identifier, identifier, identifier],
    );
    if (!result.affectedRows) {
      console.error(`No account matched "${identifier}".`);
      process.exitCode = 1;
      return;
    }
    console.log(`Granted the ${role} role to "${identifier}".`);
  } finally {
    await connection.end();
  }
}

grant().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
