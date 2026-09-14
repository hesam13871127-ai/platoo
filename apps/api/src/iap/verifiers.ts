import { createSign } from 'node:crypto';

export type IapEnvironment = 'production' | 'sandbox';

/**
 * Facts about a purchase as confirmed by the store itself. The service credits coins
 * from OUR catalog row, but only after a verifier returns one of these: the client
 * can claim anything, the store API is the source of truth.
 */
export interface VerifiedPurchase {
  provider: 'apple' | 'google';
  storeProductId: string;
  transactionId: string;
  purchasedAt: string;
  environment: IapEnvironment;
}

export interface ReceiptVerifyInput {
  /** Our user id. Must match the account marker the app attached at purchase time. */
  userId: string;
  /** Expected store product id, taken from OUR catalog row (never from the client alone). */
  storeProductId: string;
  transactionId: string;
  receipt: string;
  /** Expected Apple bundle id / Play package name. */
  expectedPackage: string;
}

export type VerificationFailureKind = 'invalid' | 'unavailable' | 'transient';

export class ReceiptVerificationError extends Error {
  constructor(message: string, readonly kind: VerificationFailureKind) {
    super(message);
    this.name = 'ReceiptVerificationError';
  }
}

export interface ReceiptVerifier {
  readonly provider: 'apple' | 'google';
  verify(input: ReceiptVerifyInput): Promise<VerifiedPurchase>;
  /** Post-credit acknowledgement (Google Play requires it). Best-effort by contract. */
  acknowledge?(input: ReceiptVerifyInput): Promise<void>;
}

function base64UrlEncode(data: string | Buffer): string {
  return Buffer.from(data).toString('base64url');
}

function base64UrlDecodeToJson<T>(segment: string): T {
  return JSON.parse(Buffer.from(segment, 'base64url').toString('utf8')) as T;
}

async function fetchJson(url: string, init: RequestInit, context: string): Promise<{ status: number; body: any }> {
  let response: Response;
  try {
    response = await fetch(url, { ...init, signal: AbortSignal.timeout(12_000) });
  } catch {
    throw new ReceiptVerificationError(`${context} is unreachable. Try again in a moment.`, 'transient');
  }
  let body: any = null;
  try {
    body = await response.json();
  } catch {
    body = null;
  }
  return { status: response.status, body };
}

function signJwt(header: object, payload: object, privateKey: string, algorithm: 'RSA-SHA256' | 'sha256'): string {
  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(payload))}`;
  const signer = createSign(algorithm);
  signer.update(unsigned);
  signer.end();
  return `${unsigned}.${signer.sign(privateKey).toString('base64url')}`;
}

export interface AppleIapSettings {
  issuerId: string;
  keyId: string;
  /** .p8 private key contents (PEM). */
  privateKey: string;
  bundleId: string;
  sandbox: boolean;
}

interface AppleTransactionPayload {
  transactionId?: string;
  productId?: string;
  bundleId?: string;
  purchaseDate?: number;
  revocationDate?: number;
  type?: string;
  environment?: string;
  appAccountToken?: string;
}

/**
 * Apple App Store Server API verifier. Looks the transaction up server-side, so a
 * forged client receipt is worthless: only Apple can mint a record for a real payment.
 *
 * The app MUST pass the user's id as `appAccountToken` when purchasing; otherwise the
 * purchase cannot be bound to an account and is rejected. Matching `appAccountToken`
 * is what stops one user from redeeming another user's transaction id.
 */
export class AppleAppStoreVerifier implements ReceiptVerifier {
  readonly provider = 'apple' as const;

  constructor(private readonly settings: AppleIapSettings) {}

  private get host(): string {
    return this.settings.sandbox
      ? 'https://api.storekit-sandbox.itunes.apple.com'
      : 'https://api.storekit.itunes.apple.com';
  }

  async verify(input: ReceiptVerifyInput): Promise<VerifiedPurchase> {
    if (!this.settings.issuerId || !this.settings.keyId || !this.settings.privateKey) {
      throw new ReceiptVerificationError('Apple In-App Purchase is not configured on this server.', 'unavailable');
    }
    this.crossCheckClientReceipt(input);
    const now = Math.floor(Date.now() / 1000);
    let token: string;
    try {
      token = signJwt(
        { alg: 'ES256', kid: this.settings.keyId, typ: 'JWT' },
        { iss: this.settings.issuerId, iat: now, exp: now + 3600, aud: 'appstoreconnect-v1', bid: this.settings.bundleId },
        this.settings.privateKey,
        'sha256',
      );
    } catch {
      throw new ReceiptVerificationError('Apple In-App Purchase credentials are invalid.', 'unavailable');
    }
    const { status, body } = await fetchJson(
      `${this.host}/inApps/v1/transactions/${encodeURIComponent(input.transactionId)}`,
      { headers: { Authorization: `Bearer ${token}` } },
      'The App Store',
    );
    if (status === 401 || status === 403) {
      throw new ReceiptVerificationError('The App Store rejected this server\u2019s credentials.', 'unavailable');
    }
    if (status === 404) throw new ReceiptVerificationError('The App Store has no record of this transaction.', 'invalid');
    if (status === 429 || status >= 500) {
      throw new ReceiptVerificationError('The App Store is temporarily unavailable. Try again in a moment.', 'transient');
    }
    if (status !== 200 || typeof body?.signedTransactionInfo !== 'string') {
      throw new ReceiptVerificationError('The App Store returned an unexpected response.', 'transient');
    }
    let tx: AppleTransactionPayload;
    try {
      tx = base64UrlDecodeToJson<AppleTransactionPayload>(String(body.signedTransactionInfo).split('.')[1]);
    } catch {
      throw new ReceiptVerificationError('The App Store returned an unreadable transaction.', 'transient');
    }
    if (tx.transactionId !== input.transactionId) {
      throw new ReceiptVerificationError('The App Store record does not match this transaction.', 'invalid');
    }
    if (tx.productId !== input.storeProductId) {
      throw new ReceiptVerificationError('This transaction is for a different product.', 'invalid');
    }
    if (tx.bundleId !== input.expectedPackage) {
      throw new ReceiptVerificationError('This purchase was made in a different app.', 'invalid');
    }
    if (tx.type !== 'Consumable') {
      throw new ReceiptVerificationError('Only consumable coin packs can be redeemed.', 'invalid');
    }
    if (typeof tx.revocationDate === 'number') {
      throw new ReceiptVerificationError('This purchase was revoked by the App Store.', 'invalid');
    }
    const environment: IapEnvironment = tx.environment === 'Production' ? 'production' : 'sandbox';
    if (this.settings.sandbox !== (environment === 'sandbox')) {
      throw new ReceiptVerificationError('This receipt comes from the wrong App Store environment.', 'invalid');
    }
    if (!tx.appAccountToken || tx.appAccountToken.toLowerCase() !== input.userId.toLowerCase()) {
      throw new ReceiptVerificationError(
        'This purchase is not linked to your account. Complete the purchase while signed in as yourself.',
        'invalid',
      );
    }
    if (typeof tx.purchaseDate !== 'number') {
      throw new ReceiptVerificationError('The App Store record is missing its purchase date.', 'invalid');
    }
    return {
      provider: 'apple',
      storeProductId: tx.productId,
      transactionId: tx.transactionId,
      purchasedAt: new Date(tx.purchaseDate).toISOString(),
      environment,
    };
  }

  /**
   * Defense in depth for StoreKit 2: when the client hands us a JWS transaction, its id
   * must agree with the transaction we look up. Trust still comes from Apple's API over
   * TLS; this only catches mixed-up client payloads early.
   */
  private crossCheckClientReceipt(input: ReceiptVerifyInput): void {
    const segments = input.receipt.split('.');
    if (segments.length !== 3) return; // StoreKit 1 style receipt: nothing to cross-check.
    try {
      const payload = base64UrlDecodeToJson<{ transactionId?: string }>(segments[1]);
      if (payload.transactionId && payload.transactionId !== input.transactionId) {
        throw new ReceiptVerificationError('The receipt does not match this transaction.', 'invalid');
      }
    } catch (error) {
      if (error instanceof ReceiptVerificationError) throw error;
      // Unparseable JWS: ignore here, the authoritative lookup above still decides.
    }
  }
}

export interface GoogleIapSettings {
  serviceAccountEmail: string;
  /** Service-account private key contents (PEM). */
  privateKey: string;
  packageName: string;
}

interface GooglePurchase {
  purchaseState?: number;
  productId?: string;
  orderId?: string;
  purchaseTimeMillis?: string;
  acknowledgementState?: number;
  obfuscatedExternalAccountId?: string;
}

/**
 * Google Play Developer API verifier. Same trust model as Apple: the purchase token is
 * resolved server-side and the token's authoritative record decides.
 *
 * The app MUST set `obfuscatedExternalAccountId` to the user's id when launching the
 * billing flow; purchases without a matching marker are rejected, which stops
 * cross-account replay of purchase tokens.
 */
export class GooglePlayVerifier implements ReceiptVerifier {
  readonly provider = 'google' as const;
  private tokenCache: { token: string; expiresAt: number } | null = null;

  constructor(private readonly settings: GoogleIapSettings) {}

  async verify(input: ReceiptVerifyInput): Promise<VerifiedPurchase> {
    if (!this.settings.serviceAccountEmail || !this.settings.privateKey || !this.settings.packageName) {
      throw new ReceiptVerificationError('Google Play billing is not configured on this server.', 'unavailable');
    }
    const accessToken = await this.accessToken();
    const purchase = await this.fetchPurchase(input, accessToken);
    if (purchase.purchaseState !== 0) {
      throw new ReceiptVerificationError('Google Play reports this purchase is not completed.', 'invalid');
    }
    if (purchase.productId !== input.storeProductId) {
      throw new ReceiptVerificationError('This purchase is for a different product.', 'invalid');
    }
    if (purchase.orderId !== input.transactionId) {
      throw new ReceiptVerificationError('The Play record does not match this transaction.', 'invalid');
    }
    if (!purchase.obfuscatedExternalAccountId || purchase.obfuscatedExternalAccountId.toLowerCase() !== input.userId.toLowerCase()) {
      throw new ReceiptVerificationError(
        'This purchase is not linked to your account. Complete the purchase while signed in as yourself.',
        'invalid',
      );
    }
    const purchasedAt = purchase.purchaseTimeMillis ? new Date(Number(purchase.purchaseTimeMillis)).toISOString() : new Date().toISOString();
    return { provider: 'google', storeProductId: purchase.productId, transactionId: purchase.orderId, purchasedAt, environment: 'production' };
  }

  /**
   * Google auto-refunds purchases that stay unacknowledged for 3 days, so the service
   * calls this right after crediting. Failures are retried by operations, never by
   * taking the coins back: acknowledgement must not be able to revoke a credit.
   */
  async acknowledge(input: ReceiptVerifyInput): Promise<void> {
    const accessToken = await this.accessToken();
    const { status } = await fetchJson(
      this.purchaseUrl(input, ':acknowledge'),
      { method: 'POST', headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' }, body: '{}' },
      'Google Play',
    );
    if (status !== 200 && status !== 204) throw new Error(`Play acknowledge rejected (HTTP ${status}).`);
  }

  private purchaseUrl(input: ReceiptVerifyInput, suffix = ''): string {
    return (
      `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(this.settings.packageName)}` +
      `/purchases/products/${encodeURIComponent(input.storeProductId)}/tokens/${encodeURIComponent(input.receipt)}${suffix}`
    );
  }

  private async fetchPurchase(input: ReceiptVerifyInput, accessToken: string): Promise<GooglePurchase> {
    const { status, body } = await fetchJson(
      this.purchaseUrl(input),
      { headers: { Authorization: `Bearer ${accessToken}` } },
      'Google Play',
    );
    if (status === 401 || status === 403) {
      throw new ReceiptVerificationError('Google Play rejected this server\u2019s credentials.', 'unavailable');
    }
    if (status === 400 || status === 404 || status === 410) {
      throw new ReceiptVerificationError('Google Play has no record of this purchase.', 'invalid');
    }
    if (status === 429 || status >= 500) {
      throw new ReceiptVerificationError('Google Play is temporarily unavailable. Try again in a moment.', 'transient');
    }
    if (status !== 200 || typeof body !== 'object' || body === null) {
      throw new ReceiptVerificationError('Google Play returned an unexpected response.', 'transient');
    }
    return body as GooglePurchase;
  }

  private async accessToken(): Promise<string> {
    if (this.tokenCache && this.tokenCache.expiresAt > Date.now() + 60_000) return this.tokenCache.token;
    const now = Math.floor(Date.now() / 1000);
    let assertion: string;
    try {
      assertion = signJwt(
        { alg: 'RS256', typ: 'JWT' },
        {
          iss: this.settings.serviceAccountEmail,
          sub: this.settings.serviceAccountEmail,
          scope: 'https://www.googleapis.com/auth/androidpublisher',
          aud: 'https://oauth2.googleapis.com/token',
          iat: now,
          exp: now + 3600,
        },
        this.settings.privateKey,
        'RSA-SHA256',
      );
    } catch {
      throw new ReceiptVerificationError('Google Play service-account credentials are invalid.', 'unavailable');
    }
    const params = new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion });
    const { status, body } = await fetchJson(
      'https://oauth2.googleapis.com/token',
      { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: params.toString() },
      'Google OAuth',
    );
    if (status !== 200 || typeof body?.access_token !== 'string') {
      throw new ReceiptVerificationError('Google Play authentication failed.', status >= 500 ? 'transient' : 'unavailable');
    }
    this.tokenCache = { token: body.access_token, expiresAt: Date.now() + Number(body.expires_in ?? 3600) * 1000 };
    return this.tokenCache.token;
  }
}

/**
 * Development-only verifier. Accepts JSON test receipts of the form
 * `{"test":true,"transactionId":"...","productId":"...","userId":"..."}` and still
 * enforces product + transaction + account binding, so the idempotency and replay
 * paths can be exercised end to end without store credentials.
 *
 * The service only selects this verifier when DEV_IAP_ENABLED=true outside production,
 * and main.ts refuses to boot production with DEV_IAP_ENABLED set.
 */
export class DevReceiptVerifier implements ReceiptVerifier {
  constructor(readonly provider: 'apple' | 'google') {}

  async verify(input: ReceiptVerifyInput): Promise<VerifiedPurchase> {
    let test: { test?: boolean; transactionId?: string; productId?: string; userId?: string };
    try {
      test = JSON.parse(input.receipt) as typeof test;
    } catch {
      throw new ReceiptVerificationError(
        'Test receipts must be JSON: {"test":true,"transactionId":"...","productId":"...","userId":"..."}.',
        'invalid',
      );
    }
    if (test.test !== true) throw new ReceiptVerificationError('Test receipts must carry {"test":true}.', 'invalid');
    if (test.transactionId !== input.transactionId || test.productId !== input.storeProductId) {
      throw new ReceiptVerificationError('The test receipt does not match this purchase.', 'invalid');
    }
    if (!test.userId || test.userId !== input.userId) {
      throw new ReceiptVerificationError('This test receipt belongs to a different user.', 'invalid');
    }
    return {
      provider: this.provider,
      storeProductId: input.storeProductId,
      transactionId: input.transactionId,
      purchasedAt: new Date().toISOString(),
      environment: 'sandbox',
    };
  }
}
