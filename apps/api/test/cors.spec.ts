import { isAllowedOrigin, corsOriginOption, socketCorsOrigin } from '../src/common/cors.util';

describe('CORS utility', () => {
  describe('isAllowedOrigin', () => {
    it('allows any origin when origin is undefined (mobile apps, Postman, curl)', () => {
      expect(isAllowedOrigin(undefined, ['http://example.com'], true)).toBe(true);
      expect(isAllowedOrigin(undefined, [], false)).toBe(true);
    });

    it('allows exact matches in production', () => {
      expect(isAllowedOrigin('https://vibetable.com', ['https://vibetable.com'], true)).toBe(true);
      expect(isAllowedOrigin('https://malicious.com', ['https://vibetable.com'], true)).toBe(false);
    });

    it('allows any localhost/127.0.0.1 port in development', () => {
      expect(isAllowedOrigin('http://localhost:60797', ['http://localhost:3000'], false)).toBe(true);
      expect(isAllowedOrigin('http://127.0.0.1:5173', [], false)).toBe(true);
      expect(isAllowedOrigin('http://localhost:8080', ['http://localhost:3000'], false)).toBe(true);
    });

    it('allows custom dev origin in development', () => {
      expect(isAllowedOrigin('http://localhost:1234', [], false)).toBe(true);
    });
  });

  describe('corsOriginOption', () => {
    it('returns false in production when no origins configured', () => {
      expect(corsOriginOption([], true)).toBe(false);
    });

    it('returns a callback in production that enforces configured origins', (done) => {
      const option = corsOriginOption(['https://vibetable.com'], true);
      expect(typeof option).toBe('function');
      if (typeof option === 'function') {
        option('https://vibetable.com', (err, allow) => {
          expect(err).toBeNull();
          expect(allow).toBe(true);
          option('https://evil.com', (err2, allow2) => {
            expect(err2).toBeNull();
            expect(allow2).toBe(false);
            done();
          });
        });
      }
    });

    it('returns a callback function in development that accepts dev origins', (done) => {
      const option = corsOriginOption(['http://localhost:3000'], false);
      expect(typeof option).toBe('function');
      if (typeof option === 'function') {
        option('http://localhost:60797', (err, allow) => {
          expect(err).toBeNull();
          expect(allow).toBe(true);
          done();
        });
      }
    });
  });

  describe('socketCorsOrigin', () => {
    const originalEnv = process.env;

    beforeEach(() => {
      process.env = { ...originalEnv };
    });

    afterAll(() => {
      process.env = originalEnv;
    });

    it('allows dev connections when NODE_ENV is development', (done) => {
      process.env.NODE_ENV = 'development';
      process.env.CORS_ORIGINS = 'http://localhost:3000';
      const handler = socketCorsOrigin();
      expect(typeof handler).toBe('function');
      handler('http://localhost:60797', (err: any, allow: boolean) => {
        expect(err).toBeNull();
        expect(allow).toBe(true);
        done();
      });
    });
  });
});
