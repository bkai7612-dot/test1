// Receives RevenueCat webhooks and keeps profiles.plan in sync.
//
// Rather than trusting the event's contents, it asks RevenueCat for the
// customer's current entitlements and writes the result. That makes every
// event type (purchase, renewal, cancellation, expiry, refund, transfer)
// safe to handle the same way, and replays harmless.
//
// Secrets (Supabase dashboard → Edge Functions → Secrets):
//   REVENUECAT_WEBHOOK_AUTH  the Authorization header value set in RevenueCat
//   REVENUECAT_SECRET_KEY    a RevenueCat secret API key (sk_…)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.

import { createClient } from 'npm:@supabase/supabase-js@2';

const ENTITLEMENT = 'plus';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

interface RcEntitlement {
  expires_date: string | null;
  product_identifier: string;
}

interface RcSubscriber {
  entitlements: Record<string, RcEntitlement>;
  subscriptions: Record<string, { store: string }>;
  non_subscriptions: Record<string, { store: string }[]>;
}

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}

async function fetchSubscriber(appUserId: string): Promise<RcSubscriber> {
  const base = Deno.env.get('REVENUECAT_API_URL') ?? 'https://api.revenuecat.com';
  const res = await fetch(`${base}/v1/subscribers/${encodeURIComponent(appUserId)}`, {
    headers: { Authorization: `Bearer ${Deno.env.get('REVENUECAT_SECRET_KEY')}` },
  });
  if (!res.ok) throw new Error(`RevenueCat returned ${res.status}`);
  const body = await res.json();
  return body.subscriber as RcSubscriber;
}

/** Works out the plan from RevenueCat's view of the customer. */
function planFrom(subscriber: RcSubscriber) {
  const ent = subscriber.entitlements?.[ENTITLEMENT];
  const active = Boolean(ent) && (ent.expires_date === null || new Date(ent.expires_date) > new Date());
  if (!active || !ent) return { plan: 'free', plan_expires_at: null, plan_source: null };
  const pid = ent.product_identifier;
  const store = subscriber.subscriptions?.[pid]?.store ?? subscriber.non_subscriptions?.[pid]?.[0]?.store ?? null;
  // Web Billing purchases report as "rc_billing" or "stripe"; group them as "stripe".
  const source = store === 'rc_billing' ? 'stripe' : store;
  return { plan: 'plus', plan_expires_at: ent.expires_date, plan_source: source };
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const expected = Deno.env.get('REVENUECAT_WEBHOOK_AUTH');
  if (!expected || req.headers.get('Authorization') !== expected) {
    return json({ error: 'Unauthorised' }, 401);
  }

  let event: Record<string, unknown>;
  try {
    event = (await req.json()).event ?? {};
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }

  // Every id this event could concern (transfers name both sides).
  const ids = new Set<string>();
  for (const key of ['app_user_id', 'original_app_user_id']) {
    const v = event[key];
    if (typeof v === 'string') ids.add(v);
  }
  for (const key of ['aliases', 'transferred_from', 'transferred_to']) {
    const v = event[key];
    if (Array.isArray(v)) v.forEach((x) => typeof x === 'string' && ids.add(x));
  }
  const userIds = [...ids].filter((id) => UUID.test(id));
  if (!userIds.length) return json({ ok: true, skipped: 'no Homefolio user id' });

  const results: Record<string, string> = {};
  for (const userId of userIds) {
    try {
      const subscriber = await fetchSubscriber(userId);
      const values = planFrom(subscriber);
      const { error } = await admin.from('profiles').update(values).eq('id', userId);
      if (error) throw error;
      results[userId] = values.plan;
    } catch (err) {
      console.error('Failed to update plan', userId, err);
      // A 500 makes RevenueCat retry the webhook later.
      return json({ error: 'Update failed' }, 500);
    }
  }
  return json({ ok: true, type: event.type ?? null, results });
});
