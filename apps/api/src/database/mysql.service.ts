import { Injectable, Logger, OnApplicationShutdown, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import mysql, { Pool, PoolConnection, ResultSetHeader, RowDataPacket } from 'mysql2/promise';

export type SqlParams = readonly unknown[];

@Injectable()
export class MysqlService implements OnModuleInit, OnApplicationShutdown {
  private readonly logger = new Logger(MysqlService.name);
  private readonly pool: Pool;

  constructor(private readonly config: ConfigService) {
    this.pool = mysql.createPool({
      host: this.config.getOrThrow<string>('database.host'),
      port: this.config.getOrThrow<number>('database.port'),
      user: this.config.getOrThrow<string>('database.user'),
      password: this.config.getOrThrow<string>('database.password'),
      database: this.config.getOrThrow<string>('database.name'),
      waitForConnections: true,
      connectionLimit: this.config.get<number>('database.connectionLimit', 10),
      queueLimit: 0,
      timezone: 'Z',
      dateStrings: true,
      namedPlaceholders: false,
      supportBigNumbers: true,
      bigNumberStrings: false,
    });
  }

  async onModuleInit(): Promise<void> {
    const connection = await this.pool.getConnection();
    connection.release();
    this.logger.log('MySQL connection pool ready');
  }

  async query<T extends RowDataPacket[] = RowDataPacket[]>(sql: string, params: SqlParams = []): Promise<T> {
    const [rows] = await this.pool.query<T>(sql, params as unknown[]);
    return rows;
  }

  async execute(sql: string, params: SqlParams = []): Promise<ResultSetHeader> {
    const [result] = await this.pool.execute<ResultSetHeader>(sql, params as any[]);
    return result;
  }

  async transaction<T>(callback: (connection: PoolConnection) => Promise<T>): Promise<T> {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const result = await callback(connection);
      await connection.commit();
      return result;
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  }

  async ping(): Promise<boolean> {
    try {
      await this.pool.query('SELECT 1');
      return true;
    } catch {
      return false;
    }
  }

  async onApplicationShutdown(): Promise<void> {
    await this.pool.end();
  }
}
