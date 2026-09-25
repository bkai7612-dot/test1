/**
 * Homefolio Plus purchases through RevenueCat.
 *
 * - iPhone / Android: native in-app purchases (@revenuecat/purchases-capacitor).
 * - Web: RevenueCat Web Billing, which uses your Stripe account (@revenuecat/purchases-js).
 * - Windows app: opens the web app's upgrade page in the browser (see Upgrade.tsx).
 *
 * The purchase itself never unlocks anything directly. RevenueCat notifies the
 * `revenuecat-webhook` Supabase function, which sets profiles.plan; the app then
 * re-reads the profile. That keeps one source of truth across every device.
 */
import { FriendlyError } from './errors';
import { platform } from './platform';

export type PlanKind = 'monthly' | 'annual' | 'lifetime';

export interface PlanOption {
  kind: PlanKind;
  price: string;
  /** SDK package object, passed back to purchase(). */
  pkg: unknown;
}

export type PurchaseOutcome = 'purchased' | 'cancelled';

export const ENTITLEMENT = 'plus';

/** Shown when the store can't be reached (and in the prototype). */
export const FALLBACK_PRICES: Record<PlanKind, string> = {
  monthly: '£2.99',
  annual: '£24.99',
  lifetime: '£59',
};

const KIND_ORDER: PlanKind[] = ['annual', 'monthly', 'lifetime'];

function apiKey(): string | undefined {
  if (platform === 'ios') return import.meta.env.VITE_REVENUECAT_IOS_KEY;
  if (platform === 'android') return import.meta.env.VITE_REVENUECAT_ANDROID_KEY;
  if (platform === 'web') return import.meta.env.VITE_REVENUECAT_WEB_KEY;
  return undefined;
}

/** True where Homefolio can take payment in-app (not the Windows app, not unconfigured builds). */
export function purchasesAvailable(): boolean {
  return platform !== 'desktop' && Boolean(apiKey()) && !import.meta.env.VITE_DEMO;
}

let configuredFor: string | null = null;

async function nativeSdk(userId: string) {
  const { Purchases } = await import('@revenuecat/purchases-capacitor');
  if (configuredFor !== userId) {
    const { isConfigured } = await Purchases.isConfigured();
    if (!isConfigured) await Purchases.configure({ apiKey: apiKey()!, appUserID: userId });
    else await Purchases.logIn({ appUserID: userId });
    configuredFor = userId;
  }
  return Purchases;
}

async function webSdk(userId: string) {
  const { Purchases } = await import('@revenuecat/purchases-js');
  if (!Purchases.isConfigured()) {
    configuredFor = userId;
    return Purchases.configure({ apiKey: apiKey()!, appUserId: userId });
  }
  const instance = Purchases.getSharedInstance();
  if (configuredFor !== userId) {
    await instance.changeUser(userId);
    configuredFor = userId;
  }
  return instance;
}

function nativeKind(type: string): PlanKind | null {
  if (type === 'MONTHLY') return 'monthly';
  if (type === 'ANNUAL') return 'annual';
  if (type === 'LIFETIME') return 'lifetime';
  return null;
}

function webKind(type: string): PlanKind | null {
  if (type === '$rc_monthly') return 'monthly';
  if (type === '$rc_annual') return 'annual';
  if (type === '$rc_lifetime') return 'lifetime';
  return null;
}

export async function getPlanOptions(userId: string): Promise<PlanOption[]> {
  if (!purchasesAvailable()) return [];
  let options: PlanOption[] = [];
  if (platform === 'web') {
    const sdk = await webSdk(userId);
    const offerings = await sdk.getOfferings();
    options = (offerings.current?.availablePackages ?? []).flatMap((p) => {
      const kind = webKind(p.packageType);
      return kind ? [{ kind, price: p.webBillingProduct.currentPrice.formattedPrice, pkg: p }] : [];
    });
  } else {
    const sdk = await nativeSdk(userId);
    const offerings = await sdk.getOfferings();
    options = (offerings.current?.availablePackages ?? []).flatMap((p) => {
      const kind = nativeKind(String(p.packageType));
      return kind ? [{ kind, price: p.product.priceString, pkg: p }] : [];
    });
  }
  return options.sort((a, b) => KIND_ORDER.indexOf(a.kind) - KIND_ORDER.indexOf(b.kind));
}

export async function purchase(userId: string, option: PlanOption, email?: string): Promise<PurchaseOutcome> {
  try {
    if (platform === 'web') {
      const sdk = await webSdk(userId);
      await sdk.purchase({ rcPackage: option.pkg as never, customerEmail: email });
    } else {
      const sdk = await nativeSdk(userId);
      await sdk.purchasePackage({ aPackage: option.pkg as never });
    }
    return 'purchased';
  } catch (err) {
    const e = err as { userCancelled?: boolean; errorCode?: number; code?: string };
    // Web SDK: errorCode 1 = UserCancelledError. Native: userCancelled flag.
    if (e.userCancelled || e.errorCode === 1 || e.code === '1') return 'cancelled';
    throw new FriendlyError("The purchase didn't go through. You haven't been charged. Please try again.");
  }
}

/** Apple requires a Restore Purchases button. Returns true if Plus is active afterwards. */
export async function restorePurchases(userId: string): Promise<boolean> {
  if (platform !== 'ios' && platform !== 'android') return false;
  const sdk = await nativeSdk(userId);
  const { customerInfo } = await sdk.restorePurchases();
  return Boolean(customerInfo.entitlements.active[ENTITLEMENT]);
}

/** Where the user manages or cancels their subscription. */
export async function manageSubscriptionUrl(userId: string, source: string | null): Promise<string | null> {
  if (source === 'app_store') return 'https://apps.apple.com/account/subscriptions';
  if (source === 'play_store') return 'https://play.google.com/store/account/subscriptions?package=uk.co.homefolio.app';
  if (platform === 'web' && purchasesAvailable()) {
    const sdk = await webSdk(userId);
    const info = await sdk.getCustomerInfo();
    return info.managementURL;
  }
  return null;
}
