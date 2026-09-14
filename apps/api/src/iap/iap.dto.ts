import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export const IAP_PROVIDERS = ['apple', 'google'] as const;
export type IapProvider = (typeof IAP_PROVIDERS)[number];

/**
 * Sent by the app after the store reports a completed purchase.
 *
 * - Apple (StoreKit 2): `transactionId` is the transaction id and `receipt` is the
 *   JWS transaction. StoreKit 1 base64 receipts are accepted as opaque blobs too.
 * - Google: `transactionId` is the Play `orderId` and `receipt` is the purchase token.
 *
 * The server never trusts the client about what was bought: the product grant comes
 * from OUR `iap_products` catalog and the purchase facts come from the store's API.
 */
export class VerifyPurchaseDto {
  @IsIn([...IAP_PROVIDERS])
  provider!: IapProvider;

  @IsString()
  @MinLength(1)
  @MaxLength(120)
  storeProductId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(160)
  transactionId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(20000)
  receipt!: string;
}
