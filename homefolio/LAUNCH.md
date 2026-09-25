# Homefolio launch guide

Everything is built. This guide is the list of things only you can do: open accounts, pay fees, paste keys, and press the release buttons. Work through it in order. Each step says exactly where to click and what to paste.

You never need to build anything on your own computer. GitHub builds the Windows, iPhone and Android apps for you in the cloud.

---

## What you pay

Prices checked September 2026. Dollar prices are charged in dollars; the £ figures are approximate.

### Required

| What | Why | One-off | Recurring |
| --- | --- | --- | --- |
| Apple Developer Program | Publish on the App Store | — | $99 / year (about £79) |
| Google Play Console | Publish on Google Play | $25 (about £20) | — |
| Supabase Pro | The database, sign-in and file storage for every app | — | $25 / month (about £20) |
| Domain names (homefolio.co.uk + homefolio.com) | Website, web app and email addresses | — | about £20 / year |
| ICO data protection fee | Legally required in the UK to hold personal data | — | £52 / year (£47 by Direct Debit) |
| Windows code signing | Stops Windows warning people about the installer | — | $9.99 / month with Azure Artifact Signing (about £96 / year), **or** about £150–£350 / year for an SSL.com certificate |
| Website hosting | Vercel Pro: required once the site earns money (ads, Plus) | — | $20 / month (about £190 / year) |

**First-year total: about £700–£950.** After that, about £680–£930 a year.

To save about £190 a year you can host the two websites on Cloudflare Pages (free, commercial use allowed) instead of Vercel. The steps below use Vercel because it's simpler.

### Free to start (pay only when you grow)

| What | Free allowance | Then |
| --- | --- | --- |
| RevenueCat (manages Plus purchases) | Free until $2,500 revenue a month | 1% of revenue |
| Resend (sends sign-up and password emails) | Free tier covers launch | Paid plan when you outgrow it |
| Cloudflare (DNS and email forwarding) | Free | — |
| GitHub (code and builds) | Free; the releases repository is public | If builds exceed the free minutes: GitHub Pro $4 / month |

### Taken from sales

| Where the sale happens | Fee |
| --- | --- |
| iPhone app (Apple) | 15% (after joining Apple's Small Business Program) |
| Android app (Google) | 15% on subscriptions |
| Web and Windows (Stripe) | about 1.5% + 20p per UK card payment |

### Optional

| What | Cost |
| --- | --- |
| UK trademark for "Homefolio" (one class) | from about £170 |
| Solicitor review of the privacy policy and terms | varies |

---

## What's in the box

| Folder / file | What it is |
| --- | --- |
| `homefolio/` | The app: the same code runs on the web, Windows, iPhone and Android |
| `homefolio/src-tauri/` | The Windows app wrapper |
| `homefolio/ios/`, `homefolio/android/` | The iPhone and Android app projects |
| `homefolio/supabase/` | Database setup and the payment webhook |
| `homefolio/website/` | The website: home, download, Plus, advertise, support, privacy, terms |
| `homefolio/release-assets/` | App Store and Google Play screenshots, icons, feature graphic, and **store-listing.md** (all the text to paste) |
| `.github/workflows/homefolio-*.yml` | The cloud builds for Windows, iPhone, Android and the database |
| **homefolio-private-keys.zip** (sent separately, not in the code) | Your Windows update key and Android upload key |

---

## Step 0 · Put the code on your main branch (5 minutes)

The code is on the branch `claude/trusting-dijkstra-4fmqcy` of your GitHub repository `bkai7612-dot/test1`. The build buttons only appear once it's on `main`.

1. Open https://github.com/bkai7612-dot/test1.
2. Click **Compare & pull request** for that branch (or ask Claude to open the pull request), then **Merge**.

---

## Step 1 · Start the slow accounts first (day 1)

Some of these take days to verify, so start them now.

1. **Decide: company or individual?** A registered company skips Google's 14-day testing rule and can use the cheaper Azure signing. As an individual, your own name appears as the seller.
2. **Apple Developer Program**: https://developer.apple.com/programs/enroll/ → pay $99. As a company you first need a free D-U-N-S number (Apple links to it during enrolment; it can take a week or more).
3. **Google Play Console**: https://play.google.com/console/signup → pay $25 and verify your identity.
4. **Windows code signing** (choose one):
   - **Azure Artifact Signing** ($9.99/month): https://azure.microsoft.com/products/artifact-signing. Create an Azure account, an Artifact Signing account and an identity validation. Organisations need about 3 years of trading history. The sign-up tells you if you're eligible.
   - **SSL.com OV code signing with eSigner** (for individuals and new companies): buy an "OV Code Signing" certificate with **eSigner** cloud signing. They verify your identity by video or documents.
   - You can release **without signing** to start with. It works, but Windows shows a "Windows protected your PC" warning. The download page already tells people how to click past it.
5. **ICO**: register and pay at https://ico.org.uk/for-organisations/data-protection-fee/. Note your registration number.

---

## Step 2 · Domain and email addresses (day 1)

1. Buy **homefolio.co.uk** and **homefolio.com** (Cloudflare Registrar or Namecheap).
2. Use Cloudflare for DNS (free).
3. Cloudflare → **Email → Email Routing**: forward `support@`, `privacy@`, `advertise@` and `hello@homefolio.co.uk` to your own inbox.

If you use a different domain, tell Claude and it will change every mention in one go.

---

## Step 3 · Production database (Supabase, day 1–2)

1. https://supabase.com → create an organisation **Homefolio** → upgrade to **Pro**.
2. **New project**: name `homefolio-prod`, region **London (eu-west-2)**, and a strong database password (save it in your password manager).
3. Create a second, free project `homefolio-staging` in the same way, for testing updates.
4. For each project, note down (Project Settings → General / API):
   - **Project ref** (the random id in the project URL)
   - **Project URL** (`https://<ref>.supabase.co`)
   - **Publishable (anon) key**. It's safe for apps to use. Never copy the `service_role` / secret key anywhere.
5. Create an access token: Account (top right) → **Access Tokens** → **Generate new token**. Save it.
6. **Authentication → URL Configuration**:
   - Site URL: `https://app.homefolio.co.uk`
   - Redirect URLs: add `https://app.homefolio.co.uk/**`
7. **Authentication → Providers → Email**: **Confirm email** on; minimum password length 8.
8. **Authentication → Attack Protection**: turn on leaked-password protection.
9. **Emails**: create a free account at https://resend.com, add the domain `homefolio.co.uk` and add the DNS records it shows in Cloudflare. Then Supabase **Authentication → Emails → SMTP Settings**: host `smtp.resend.com`, port `465`, username `resend`, password = your Resend API key, sender `hello@homefolio.co.uk`, name `Homefolio`.

---

## Step 4 · GitHub settings (day 2, about 30 minutes)

### 4a. The public releases repository

1. GitHub → **New repository** → name **`homefolio-releases`** → **Public** → tick "Add a README" → Create. This is where Windows installers are published (your code stays private).
2. Create a token that lets the build publish there: your avatar → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**. Name "Homefolio releases", Repository access: **Only select repositories → homefolio-releases**, Permissions: **Contents: Read and write**. Copy the token.

### 4b. Environments, variables and secrets

In `bkai7612-dot/test1` → **Settings → Environments** → create two environments: **`production`** and **`staging`**.

**In `production` → Environment variables**, add:

| Name | Value |
| --- | --- |
| `VITE_SUPABASE_URL` | production Project URL |
| `VITE_SUPABASE_ANON_KEY` | production publishable (anon) key |
| `VITE_SITE_URL` | `https://app.homefolio.co.uk` |
| `VITE_WEBSITE_URL` | `https://homefolio.co.uk` |
| `VITE_SUPPORT_EMAIL` | `support@homefolio.co.uk` |
| `SUPABASE_PROJECT_REF` | production project ref |
| `VITE_REVENUECAT_IOS_KEY` | from Step 8 (add later) |
| `VITE_REVENUECAT_ANDROID_KEY` | from Step 8 (add later) |
| `APPLE_TEAM_ID` | from Step 10 (add later) |
| `WINDOWS_SIGNING` | `none` for now; later `azure` or `sslcom` |

**In `production` → Environment secrets**, add:

| Name | Value |
| --- | --- |
| `SUPABASE_ACCESS_TOKEN` | the token from Step 3.5 |
| `SUPABASE_DB_PASSWORD` | the production database password |
| `RELEASES_TOKEN` | the token from Step 4a |
| `TAURI_SIGNING_PRIVATE_KEY` | from **READ-ME-FIRST-private-keys.txt** |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | from the same file |
| `ANDROID_KEYSTORE_BASE64` | from the same file |
| `ANDROID_KEYSTORE_PASSWORD` | from the same file |
| `ANDROID_KEY_ALIAS` | `homefolio-upload` |
| `ANDROID_KEY_PASSWORD` | from the same file |

**In `staging`**: variable `SUPABASE_PROJECT_REF` (staging ref); secrets `SUPABASE_ACCESS_TOKEN` and `SUPABASE_DB_PASSWORD` (staging password).

### 4c. Set up the databases

**Actions** tab → **Homefolio database** → **Run workflow** → target `staging` → Run. When it's green, run it again with `production`. This creates every table, the security rules, the storage and the payment webhook.

---

## Step 5 · Websites live (Vercel, day 2)

1. https://vercel.com → sign up with GitHub → upgrade to **Pro**.
2. **Add New → Project** → import `bkai7612-dot/test1`:
   - **Root Directory**: `homefolio` · Framework: Vite · Build command `npm run build` · Output `dist`
   - **Environment Variables**: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_SITE_URL`, `VITE_WEBSITE_URL`, `VITE_SUPPORT_EMAIL` (same values as 4b), and later `VITE_REVENUECAT_WEB_KEY` (Step 8).
   - Deploy, then **Settings → Domains** → add `app.homefolio.co.uk`. Add the DNS record Vercel shows in Cloudflare.
3. **Add New → Project** again, same repository:
   - **Root Directory**: `homefolio/website` · Framework: **Other** · no build command
   - Deploy, then **Domains** → add `homefolio.co.uk` and `www.homefolio.co.uk`. Add `homefolio.com` too, set to redirect to `homefolio.co.uk`.
4. **Fill in the legal details.** Open `homefolio/website/privacy.html` and `terms.html` on GitHub (click the pencil to edit). Replace every **yellow-highlighted** placeholder: company or trading name, address, company number, ICO number, publish date, and your email provider. Commit, and Vercel redeploys by itself. Have a solicitor or a GDPR template service check them if you can.
5. **Make yourself the admin** (lets you manage adverts): sign up on https://app.homefolio.co.uk with your own email, then in Supabase **SQL Editor** run:
   ```sql
   update profiles set is_admin = true
   where id = (select id from auth.users where email = 'YOUR-EMAIL@example.com');
   ```
   Refresh the app: **Settings → Manage advertising** appears.
6. **Test it**: sign up with a second email, confirm the email arrives, add a home, upload a photo, reset your password.

---

## Step 6 · Windows app (day 3)

1. **Actions** tab → **Homefolio Windows release** → **Run workflow** (or push a tag `v1.0.0`). It takes about 15 minutes.
2. Open https://github.com/bkai7612-dot/homefolio-releases/releases, where you'll find a **draft** "Homefolio 1.0.0". Download `Homefolio-Setup.exe` and try it on a Windows PC: it installs without asking for an admin password, opens by itself, and shows the sign-in screen.
3. Happy? Click **Edit → Publish release**. The website's **Download for Windows** button now serves it, and installed copies will auto-update from future releases.
4. **When your signing is approved**, go to GitHub → Settings → Environments → production:
   - **Azure**: set variable `WINDOWS_SIGNING` = `azure`, and add variables `AZURE_SIGNING_ENDPOINT` (e.g. `https://weu.codesigning.azure.net`), `AZURE_SIGNING_ACCOUNT`, `AZURE_SIGNING_PROFILE`, plus secrets `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` from an Azure "App registration" given the *Artifact Signing Certificate Profile Signer* role.
   - **SSL.com**: set `WINDOWS_SIGNING` = `sslcom`, plus secrets `ES_USERNAME`, `ES_PASSWORD`, `ES_CREDENTIAL_ID`, `ES_TOTP_SECRET` from your SSL.com eSigner account.

   Then release again. The signing steps haven't been run for real yet (they need your accounts). If the first signed build fails, send Claude the error.

---

## Step 7 · Payments: Stripe (day 3)

1. https://stripe.com → create an account for the business, then verify your identity and bank account.
2. Nothing else to do in Stripe itself. RevenueCat connects to it in Step 8.

---

## Step 8 · Homefolio Plus products (day 4, after Apple and Google accounts are approved)

Do these in order. All the names, IDs and prices are in `release-assets/store-listing.md`.

1. **App Store Connect** (https://appstoreconnect.apple.com):
   - **Business**: sign the **Paid Apps** agreement, then add your bank and tax details.
   - **Apps → + → New App**: iOS, name **Homefolio**, language English (UK), bundle ID **uk.co.homefolio.app** (register it under Certificates, Identifiers & Profiles → Identifiers if it isn't listed), SKU `homefolio`.
   - In the app: **Monetization → Subscriptions** → group "Homefolio Plus" → create `plus_monthly` and `plus_yearly`. Then **In-App Purchases** → create non-consumable `plus_lifetime`.
   - Apply for the **App Store Small Business Program** (15% fee): https://developer.apple.com/app-store/small-business-program/
2. **Google Play Console**:
   - **Create app**: name Homefolio, English (UK), App, Free.
   - **Settings → Payments profile**: set it up.
   - Products can only be created after your first upload (Step 9), so come back for them.
3. **RevenueCat** (https://www.revenuecat.com, free): follow "RevenueCat setup" in `release-assets/store-listing.md`.
   - Copy the three **public** API keys: Apple (`appl_…`), Google (`goog_…`) and Web Billing (`rcb_…`).
   - Create a **secret** API key (`sk_…`).
4. **Supabase** (production) → **Edge Functions → Secrets** → add:
   - `REVENUECAT_SECRET_KEY` = the `sk_…` key
   - `REVENUECAT_WEBHOOK_AUTH` = `Bearer ` followed by a long random password you make up (the same value goes into RevenueCat's webhook "Authorization header")
5. **GitHub** production variables: `VITE_REVENUECAT_IOS_KEY` = `appl_…`, `VITE_REVENUECAT_ANDROID_KEY` = `goog_…`.
6. **Vercel** (web app project): add `VITE_REVENUECAT_WEB_KEY` = `rcb_…`, then **Redeploy**.

---

## Step 9 · Android app (Google Play)

1. **Actions → Homefolio Android release → Run workflow** (about 10 minutes).
2. Open the finished run → **Artifacts** → download the `.aab` file (unzip it).
3. Play Console → your app → **Testing → Internal testing → Create new release** → upload the `.aab`. Leave **Play App Signing** on. Add your own email as a tester.
4. Now create the products in **Monetise → Products** (see store-listing.md), and attach them in RevenueCat.
5. Fill in **Store presence → Main store listing** and every item in **App content**, using `release-assets/store-listing.md` and the images in `release-assets/store/`.
6. **Personal account?** Create a **Closed testing** track, invite at least 15 people (they need to install it and stay opted in for 14 days in a row), then **Apply for production** on the Dashboard. **Company account?** Go straight to **Production**.
7. Production: start the rollout at 20%, then raise it to 100% after a couple of days.

After this first manual upload you can let GitHub upload future versions automatically. Create a Google Cloud service account with Play Console access, add its JSON key as secret `PLAY_SERVICE_ACCOUNT_JSON`, and set variable `PLAY_AUTO_UPLOAD` = `true`.

---

## Step 10 · iPhone and iPad app (App Store)

1. **App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → +**: name "GitHub", access **Admin** → Generate. Download the `.p8` file (you can only download it once), and note the **Key ID** and **Issuer ID**.
2. GitHub production **secrets**: `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and `APP_STORE_CONNECT_KEY_P8` (open the `.p8` file in Notepad and paste everything, including the BEGIN/END lines).
3. GitHub production **variable** `APPLE_TEAM_ID`: your 10-character Team ID (https://developer.apple.com/account → Membership details).
4. **Actions → Homefolio iOS release → Run workflow** (about 20–30 minutes). The build uploads itself to App Store Connect.
5. After about 15 minutes it appears in **TestFlight**. Install the TestFlight app on your iPhone and try everything, including a Plus purchase in sandbox mode.
6. In App Store Connect, fill the app page from `release-assets/store-listing.md`: screenshots (`release-assets/store/iphone-6.9` and `ipad-13`), description, keywords, privacy answers and the review notes. Create a reviewer account on the live app with the sample home and put its email and password under **App Review Information**.
7. Choose the build, attach the three in-app purchases, set **Manually release this version**, then **Submit for Review**. Reviews usually take 1–3 days.

---

## Step 11 · Launch day

- [ ] Windows release published and the website button downloads it
- [ ] App Store: approved → **Release this version**
- [ ] Google Play: production rollout started
- [ ] Paste the live store links into `homefolio/website/site.js` (top of the file) and commit; the "coming soon" labels disappear
- [ ] Sign up once on each platform with a fresh email; confirm the emails arrive
- [ ] Buy Plus once with a real card on the web, check it switches on, then refund yourself in Stripe

---

## Selling adverts (whenever you're ready)

1. Agree the deal (placement, dates, price) with the advertiser and get their logo, headline, text, button text and link. The specifications are on https://homefolio.co.uk/advertise.
2. In the app: **Settings → Manage advertising → New campaign**. Fill it in and Save, then use the **upload** button to add their logo.
3. The card appears to free users on that page between the start and end dates, and never to Plus users or in anyone's first week. **Pause** stops it instantly.
4. At month end: **Monthly report** → pick the month → the copy button gives you a one-line summary to email the advertiser.

---

## Releasing updates later

Ask Claude for the change. Once it's merged to `main`:

- **Website and web app** update by themselves within about a minute.
- **Database changes**: run **Homefolio database** (staging, then production).
- **Apps**: bump `"version"` in `homefolio/package.json` (e.g. `1.1.0`), then push a tag `v1.1.0` (or use **Run workflow** on each). Windows publishes a draft you **Publish**. Installed copies update themselves. Android and iPhone builds go to the stores for you to submit.

---

## If something goes wrong

- A workflow is red: open it, click the failed step, copy the last 30 lines and send them to Claude.
- Emails don't arrive: check Resend's dashboard for the domain status (all DNS records green).
- Purchases don't switch Plus on: in RevenueCat → Integrations → Webhooks, check recent deliveries (they should say 200). The usual cause is the Authorization header not matching `REVENUECAT_WEBHOOK_AUTH`.
