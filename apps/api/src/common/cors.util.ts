/**
 * Helper to check if an origin is permitted by CORS.
 * - In production: strictly match the configured CORS_ORIGINS list.
 * - In development: permit all localhost/127.0.0.1 ports (for Flutter web, Vite, etc.),
 *   as well as any configured origins or development domains.
 */
export function isAllowedOrigin(origin: string | undefined, configuredOrigins: string[], isProduction: boolean): boolean {
  if (!origin) return true;
  if (configuredOrigins.includes(origin)) return true;
  if (!isProduction) {
    // In development mode, allow localhost, 127.0.0.1, 0.0.0.0 on any port, or any origin
    if (/^https?:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)(:\d+)?$/.test(origin)) {
      return true;
    }
    // Permissive for development tooling and local browsers
    return true;
  }
  return false;
}

export function corsOriginOption(configuredOrigins: string[], isProduction: boolean) {
  if (isProduction && !configuredOrigins.length) {
    return false;
  }
  return (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    callback(null, isAllowedOrigin(origin, configuredOrigins, isProduction));
  };
}

/**
 * Socket.IO gateway CORS origin. Read from the environment at import time
 * because @WebSocketGateway options are static. Native mobile clients send
 * no Origin header, so failing closed in production does not affect the app.
 */
export function socketCorsOrigin(): any {
  const configured = (process.env.CORS_ORIGINS ?? '').split(',').map((origin) => origin.trim()).filter(Boolean);
  const isProduction = process.env.NODE_ENV === 'production';
  if (isProduction && !configured.length) {
    return false;
  }
  return (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
    callback(null, isAllowedOrigin(origin, configured, isProduction));
  };
}
