# Store listing text (copy and paste)

Everything you need to fill in App Store Connect and Google Play Console.
Screenshots and icons are in `release-assets/store/`.

---

## Both stores

**App name:** Homefolio
(If the App Store says the name is taken, use: *Homefolio: Home Organiser*)

**Bundle ID / package name:** `uk.co.homefolio.app` (already set in the app; don't change it)

**Category:** Lifestyle (Apple) · House & Home (Google)

**Price:** Free (with in-app purchases)

**Privacy policy URL:** https://homefolio.co.uk/privacy
**Support URL:** https://homefolio.co.uk/support
**Marketing URL:** https://homefolio.co.uk
**Account deletion URL (Google):** https://homefolio.co.uk/support#delete-account

---

## Apple App Store

**Subtitle (30 characters max):**
Your home, all in one place

**Promotional text (170 max):**
Never lose a receipt, manual or warranty again. Homefolio reminds you before warranties end, insurance renews and the boiler needs a service.

**Keywords (100 max, comma-separated, no spaces):**
home,house,warranty,receipt,maintenance,appliance,inventory,insurance,bills,organiser,homeowner,renter

**Description:**

Homefolio keeps everything about your home in one place: appliances, warranties, receipts, manuals, maintenance reminders, bills, insurance and emergency numbers.

WARRANTIES THAT DON'T SLIP BY
Add what you buy and when the warranty ends. Homefolio shows what's still covered and reminds you two weeks before it runs out.

RECEIPTS AND DOCUMENTS
Photograph receipts, upload manuals, insurance policies and certificates, and find them in seconds with search.

MAINTENANCE REMINDERS
Boiler service, smoke alarms, gutters, filters. Set it once; repeating tasks schedule the next one when you tick them off, and your phone reminds you on the day.

BILLS AND ACCOUNTS
Keep energy, water, broadband, council tax and insurance details together, with contract end and renewal dates.

EMERGENCY NUMBERS
Your landlord, plumber, insurer's claims line and UK emergency numbers, one tap away.

ROOM BY ROOM
Organise by room, keep a home inventory for insurance, and add your own categories and details.

WORKS EVERYWHERE
Use Homefolio on iPhone, iPad, Android, Windows and the web. Sign in once and everything stays in sync.

PRIVATE BY DESIGN
Your information is only visible to you, stored in the UK and never sold.

HOMEFOLIO PLUS
Free covers one home with 1 GB of storage. Plus adds unlimited properties, 25 GB of storage and removes sponsored cards: £2.99 a month, £24.99 a year, or £59 once.

Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel in your App Store account settings.
Terms: https://homefolio.co.uk/terms · Privacy: https://homefolio.co.uk/privacy

**What's New (version 1.0.0):**
Welcome to Homefolio.

**Age rating:** answer "None" to every question → 4+

**App Review Information → Notes:**

Homefolio stores information about a user's home: appliances, warranties, documents and maintenance reminders.

Sign in with the demo account provided. It contains an example home (Settings → Your data → Add sample home, if it's not already there).

Native features: local reminder notifications for maintenance tasks, warranty expiries and insurance renewals; the camera for photographing receipts, appliances and meters; the share sheet for documents.

In-app purchases: Homefolio Plus (monthly, yearly subscriptions and a lifetime non-consumable), in Settings → Your plan → Upgrade. Restore Purchases is on the same screen.

Account deletion: Settings → Delete account.

The app shows at most one small card labelled "Sponsored" on some pages to free users. It is chosen by page, not by personal data, and no tracking is used.

**App Privacy (nutrition label):** "Data Linked to You", none used for tracking:
- Contact Info → Email Address, Name — App Functionality
- User Content → Photos or Videos, Other User Content — App Functionality
- Identifiers → User ID — App Functionality
- Purchases → Purchase History — App Functionality

**Encryption:** the app already declares that it uses only standard encryption, so there is no export question to answer.

**In-app purchases to create (Subscriptions → group "Homefolio Plus"):**

| Reference name | Product ID | Type | Price |
| --- | --- | --- | --- |
| Plus Monthly | `plus_monthly` | Auto-renewable subscription, 1 month | £2.99 |
| Plus Yearly | `plus_yearly` | Auto-renewable subscription, 1 year | £24.99 (optional: 14-day free trial introductory offer) |
| Plus Lifetime | `plus_lifetime` | Non-consumable | £59.00 |

Display name for all: "Homefolio Plus". Description: "Unlimited properties, 25 GB storage, no sponsored cards." Add the screenshot `release-assets/store/iphone-6.9/1-dashboard.png` as the review screenshot.

---

## Google Play

**Short description (80 max):**
Warranties, receipts, maintenance reminders and bills for your home, organised.

**Full description:** use the Apple description above (Google allows 4,000 characters), replacing the last two paragraphs with:

Subscriptions renew automatically until cancelled. Manage or cancel in Google Play → Payments & subscriptions.

**Graphics:**
- App icon: `release-assets/store/google-play-icon-512.png`
- Feature graphic: `release-assets/store/google-play-feature-graphic.png`
- Phone screenshots: `release-assets/store/android-phone/` (all 5)
- Tablet screenshots (optional): `release-assets/store/ipad-13/`

**App content answers:**

| Question | Answer |
| --- | --- |
| Ads | Yes, my app contains ads |
| App access | All or some functionality is restricted → add the demo email and password |
| Content rating | Utility / productivity; no violence, no user-to-user communication, no location sharing → rated Everyone / PEGI 3 |
| Target audience | 18 and over |
| News app | No |
| Health apps | No |
| Financial features | No |
| Government app | No |
| Data safety | See below |

**Data safety form:**

| Data type | Collected | Shared | Purpose | Required? |
| --- | --- | --- | --- | --- |
| Personal info → Email address | Yes | No | Account management | Required |
| Personal info → Name | Yes | No | Account management | Optional |
| Photos and videos → Photos | Yes | No | App functionality | Optional |
| Files and docs | Yes | No | App functionality | Optional |
| Financial info → Purchase history | Yes | No | App functionality | Optional |
| App info → Other user-generated content | Yes | No | App functionality | Optional |

- Data encrypted in transit: **Yes**
- Users can request deletion: **Yes** (link: https://homefolio.co.uk/support#delete-account)

**Products to create (Monetise → Products):**

| Type | Product ID | Details | Price |
| --- | --- | --- | --- |
| Subscription | `plus` | Base plan `monthly` (auto-renewing, 1 month) | £2.99 |
| Subscription | `plus` | Base plan `yearly` (auto-renewing, 1 year), optional 14-day free-trial offer | £24.99 |
| One-time product | `plus_lifetime` | | £59.00 |

---

## RevenueCat setup (connects both stores and the web)

1. Project "Homefolio". Add three apps: App Store (bundle `uk.co.homefolio.app`), Play Store (package `uk.co.homefolio.app`), Web Billing (connect your Stripe account).
2. Entitlement: identifier **`plus`**. Attach every product above (and the three Web Billing products you create in RevenueCat: monthly £2.99, yearly £24.99, lifetime £59).
3. Offering: identifier `default`, mark as **Current**, with packages **Monthly**, **Annual** and **Lifetime**, each containing that product for all three stores.
4. Integrations → Webhooks: URL `https://<your-project-ref>.supabase.co/functions/v1/revenuecat-webhook`, Authorization header: the same value you set as `REVENUECAT_WEBHOOK_AUTH` in Supabase (for example `Bearer ` followed by a long random string).
