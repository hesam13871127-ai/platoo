/**
 * Socket.IO gateway CORS origin. Read from the environment at import time
 * because @WebSocketGateway options are static. Native mobile clients send
 * no Origin header, so failing closed in production does not affect the app.
 */
export function socketCorsOrigin(): string[] | boolean {
  const configured = (process.env.CORS_ORIGINS ?? '').split(',').map((origin) => origin.trim()).filter(Boolean);
  if (configured.length) return configured;
  return process.env.NODE_ENV === 'production' ? false : true;
}
