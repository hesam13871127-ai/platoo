/**
 * Minimal per-socket sliding-window flood guard for Socket.IO gateway events.
 * Gateways call `check()` and reject the event when it returns false.
 */
export class SocketFloodGuard {
  private readonly hits = new Map<string, number[]>();

  check(socketId: string, event: string, limit: number, windowMs: number): boolean {
    const now = Date.now();
    const key = `${socketId}:${event}`;
    const window = (this.hits.get(key) ?? []).filter((at) => at > now - windowMs);
    window.push(now);
    this.hits.set(key, window);
    if (this.hits.size > 5000 && Math.random() < 0.05) {
      for (const [stale, times] of this.hits) if (!times.length || times[times.length - 1] <= now - 60000) this.hits.delete(stale);
    }
    return window.length <= limit;
  }

  release(socketId: string): void {
    for (const key of this.hits.keys()) if (key.startsWith(`${socketId}:`)) this.hits.delete(key);
  }
}
