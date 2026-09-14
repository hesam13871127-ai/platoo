import 'reflect-metadata';
import { readdir, readFile } from 'node:fs/promises';
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
    const root = join(process.cwd(), '../../database');
    const sql = await readFile(join(root, 'schema.sql'), 'utf8');
    await connection.query(sql);
    console.log('VibeTable schema applied.');
    await connection.query(`USE \`${config.database.name}\``);
    const migrations = (await readdir(join(root, 'migrations'))).filter((file) => file.endsWith('.sql')).sort();
    for (const file of migrations) {
      await connection.query(await readFile(join(root, 'migrations', file), 'utf8'));
      console.log(`Applied migration ${file}.`);
    }
  } finally {
    await connection.end();
  }
}

migrate().catch((error: unknown) => { console.error(error); process.exitCode = 1; });
