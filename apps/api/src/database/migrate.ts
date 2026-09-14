import 'reflect-metadata';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import mysql from 'mysql2/promise';
import configuration from '../config/configuration';

async function migrate(): Promise<void> {
  const config = configuration();
  const connection = await mysql.createConnection({
    host: config.database.host,
    port: config.database.port,
    user: config.database.user,
    password: config.database.password,
    multipleStatements: true,
  });
  try {
    // Script-relative so it works from a local checkout and from the Docker image.
    const sql = await readFile(join(__dirname, '../../../../../database/schema.sql'), 'utf8');
    await connection.query(sql);
    console.log('VibeTable schema applied.');
  } finally {
    await connection.end();
  }
}

migrate().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
