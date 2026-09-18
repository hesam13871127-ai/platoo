function databaseFromUrl(): { host?: string; port?: number; user?: string; password?: string; name?: string } {
  const raw = process.env.DATABASE_URL?.trim();
  if (!raw) return {};
  try {
    const url = new URL(raw);
    return {
      host: url.hostname || undefined,
      port: url.port ? Number(url.port) : undefined,
      user: url.username ? decodeURIComponent(url.username) : undefined,
      password: url.password ? decodeURIComponent(url.password) : undefined,
      name: url.pathname.replace(/^\//, '') || undefined,
    };
  } catch {
    return {};
  }
}

export default () => {
  const fromUrl = databaseFromUrl();
  return {
    nodeEnv: process.env.NODE_ENV ?? 'development',
    port: Number(process.env.PORT ?? 3000),
    corsOrigins: (process.env.CORS_ORIGINS ?? '').split(',').map((origin) => origin.trim()).filter(Boolean),
    googleClientId: process.env.GOOGLE_CLIENT_ID ?? '',
    appleBundleId: process.env.APPLE_BUNDLE_ID ?? 'com.vibetable.app',
    database: {
      host: process.env.DB_HOST ?? fromUrl.host ?? '127.0.0.1',
      port: Number(process.env.DB_PORT ?? fromUrl.port ?? 3306),
      user: process.env.DB_USER ?? fromUrl.user ?? 'vibetable',
      password: process.env.DB_PASSWORD ?? fromUrl.password ?? 'vibetable',
      name: process.env.DB_NAME ?? fromUrl.name ?? 'vibetable',
      connectionLimit: Number(process.env.DB_CONNECTION_LIMIT ?? 10),
    },
    jwt: {
      accessSecret: process.env.JWT_ACCESS_SECRET ?? 'development-access-secret-change-me',
      refreshSecret: process.env.JWT_REFRESH_SECRET ?? 'development-refresh-secret-change-me',
      accessTtl: process.env.JWT_ACCESS_TTL ?? '15m',
      refreshTtl: process.env.JWT_REFRESH_TTL ?? '30d',
    },
    otp: {
      ttlSeconds: Number(process.env.OTP_TTL_SECONDS ?? 300),
      maxAttempts: Number(process.env.OTP_MAX_ATTEMPTS ?? 5),
      devEnabled: process.env.DEV_OTP_ENABLED === 'true',
      webhookUrl: process.env.OTP_WEBHOOK_URL ?? '',
    },
    devAdmin: {
      enabled: process.env.NODE_ENV !== 'production' && process.env.DEV_ADMIN_ENABLED !== 'false',
      username: process.env.DEV_ADMIN_USERNAME ?? 'admin',
      password: process.env.DEV_ADMIN_PASSWORD ?? 'vibetable-admin',
    },
    livekit: {
      url: process.env.LIVEKIT_URL ?? '',
      apiKey: process.env.LIVEKIT_API_KEY ?? '',
      apiSecret: process.env.LIVEKIT_API_SECRET ?? '',
    },
    redisUrl: process.env.REDIS_URL ?? '',
    rateLimit: {
      enabled: process.env.RATE_LIMIT_ENABLED !== 'false',
    },
    iap: {
      devEnabled: process.env.DEV_IAP_ENABLED === 'true',
      apple: {
        issuerId: process.env.IAP_APPLE_ISSUER_ID ?? '',
        keyId: process.env.IAP_APPLE_KEY_ID ?? '',
        privateKey: (process.env.IAP_APPLE_PRIVATE_KEY ?? '').replace(/\\n/g, '\n'),
        bundleId: process.env.APPLE_BUNDLE_ID ?? 'com.vibetable.app',
        // Sandbox stays on until explicitly disabled: production receipts are rejected while set.
        sandbox: process.env.IAP_APPLE_SANDBOX !== 'false',
      },
      google: {
        serviceAccountEmail: process.env.IAP_GOOGLE_SERVICE_ACCOUNT_EMAIL ?? '',
        privateKey: (process.env.IAP_GOOGLE_PRIVATE_KEY ?? '').replace(/\\n/g, '\n'),
        packageName: process.env.IAP_GOOGLE_PACKAGE_NAME ?? 'com.vibetable.app',
      },
    },
  };
};
