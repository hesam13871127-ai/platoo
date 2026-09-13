import 'reflect-metadata';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import mysql from 'mysql2/promise';
import configuration from '../config/configuration';

async function seed(): Promise<void> {
  const config = configuration();
  const connection = await mysql.createConnection({
    host: config.database.host,
    port: config.database.port,
    user: config.database.user,
    password: config.database.password,
    database: config.database.name,
    multipleStatements: true,
  });
  try {
    const sql = await readFile(join(process.cwd(), '../../database/seed.sql'), 'utf8');
    await connection.query(sql);
    console.log('VibeTable seed data applied.');
  } finally {
    await connection.end();
  }
}

seed().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
