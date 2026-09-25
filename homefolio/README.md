# Homefolio

> **Launching?** Start with [LAUNCH.md](./LAUNCH.md): every account, price, key and button, in order.

**Everything about your home, in one place.**

Homefolio is a free, responsive web app for homeowners and renters to keep track of their properties, rooms, appliances,
warranties, receipts, documents, maintenance, utilities, council tax, insurance, meter readings, household members and
emergency contacts.

Built with React, TypeScript, Vite, Tailwind CSS v4 and Supabase (Auth, Postgres with Row Level Security, and private
Storage).

---

## Features

| Area | What you can do |
| --- | --- |
| Accounts | Register, log in, stay logged in, log out, reset a forgotten password, change email/password, delete account |
| Properties | Several homes per account, each fully separate; switch the active home from the sidebar or top bar |
| Property profile | Address, type, ownership, bedrooms/bathrooms, year built, move-in date, notes, **custom fields**, photos |
| Dashboard | Greeting, active property, quick actions, "Upcoming" reminders, home summary counts |
| Rooms | Default and custom room types; each room lists its appliances, inventory, notes, photos and documents |
| Appliances & inventory | Full details, room, purchase info, current value, photos, receipts/manuals, custom fields |
| Warranties | Start/expiry/provider per item; automatic *Active / Expiring soon / Expired* status; warranties overview page |
| Maintenance | Tasks with due dates, rooms, appliances, photos and documents; *Overdue / Due today / Upcoming / Completed*; recurring tasks (daily → yearly, or custom) automatically create their next occurrence when completed |
| Documents | Central, searchable, filterable, paginated library; upload PDFs/images/Word/text (20 MB max); preview images and PDFs; download, edit, delete; attach to any item |
| Utilities | Electricity, gas, water, broadband and custom services; contract end reminders; bills/contracts |
| Council tax | Council, account, band, monthly amount, payment day, documents |
| Insurance | Home, contents, buildings and other policies; renewal reminders; claims line; policy documents |
| Meter readings | Electricity, gas and water history with optional meter photo and a usage chart |
| Household | Members with contact details and an emergency-contact flag |
| Emergency | Your important contacts, household emergency contacts, insurance claims lines, plus UK national numbers (tap to call — never automatic) |
| Search | One search across appliances, inventory, documents, maintenance, warranties, rooms, utilities, insurance and contacts — in the current property or all properties |
| Settings | Plan and storage, account, password, appearance (system / light / dark), reminder preferences, custom categories, data download (JSON), sample home, delete account |
| Homefolio Plus | Free plan: 1 property, 1 GB, sponsored cards. Plus (monthly, yearly, lifetime) via App Store, Google Play or Stripe through RevenueCat; unlocks unlimited properties, 25 GB, no sponsored cards |
| Sponsored cards | One small, clearly labelled card on some pages for free users; chosen by page, anonymous daily view/click totals; managed on the admin page |
| Phone features | Reminder notifications, camera, share sheet, Android back button |
| Windows app | Per-user installer that opens straight to sign-in, auto-updates, remembers window size |
| Custom data | Add your own categories for rooms, appliances, inventory, documents, utilities, maintenance and contacts, and custom "label: value" fields on properties, rooms, appliances and inventory |

Reminders are shown in the app (dashboard "Upcoming") and, on iPhone and Android, as local notifications.

---

## Getting started (local development)

### Prerequisites

- Node.js 20+
- Docker (for the local Supabase stack)

### 1. Install

```bash
cd homefolio
npm install
```

### 2. Start Supabase locally

```bash
npx supabase start          # first run downloads the Docker images
npx supabase db reset       # applies migrations + development seed data
```

`supabase start` prints an **API URL** and a **publishable/anon key**.

### 3. Configure environment

```bash
cp .env.example .env.local
# then set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY from the output above
```

### 4. Run

```bash
npm run dev                 # http://localhost:5173
```

Log in with the **development demo account** created by `supabase/seed.sql`:

- Email: `demo@homefolio.test`
- Password: `homefolio-demo`

Or register a new account (email confirmation is off locally). Emails such as password resets are captured by Mailpit at
http://127.0.0.1:54324.

### Clickable prototype (no backend)

`npm run build:demo` builds the real app against an in-browser mock backend (`src/demo/`) seeded with an example home,
bundled into a single file at `dist-demo/index.html`. Useful for sharing the design; changes reset on reload.

### Desktop and phone apps

| Command | What it does |
| --- | --- |
| `npm run tauri dev` | Run the Windows/desktop app locally (needs Rust) |
| `npm run build:desktop` | Build the web part of the desktop app (`--mode desktop`, hash routes) |
| `npm run build:mobile && npx cap sync` | Build and copy the app into the `ios/` and `android/` projects |
| `npx cap open ios` / `npx cap open android` | Open the native project in Xcode / Android Studio |

Release builds normally run on GitHub Actions (`.github/workflows/homefolio-release-*.yml`).

### Useful scripts

| Command | What it does |
| --- | --- |
| `npm run dev` | Start the Vite dev server |
| `npm run build` | Type-check and build for production into `dist/` |
| `npm run build:demo` | Build the self-contained prototype into `dist-demo/` |
| `npm run typecheck` | TypeScript only |
| `npm run format` | Format with Prettier (+ Tailwind class sorting) |
| `npm run db:reset` | Recreate the local database from migrations and seed |

---

## Deploying

1. **Create a Supabase project** at https://supabase.com.
2. **Apply the schema**: `npx supabase link --project-ref <ref>` then `npx supabase db push`
   (or paste the files in `supabase/migrations/` into the SQL editor, in order).
   Do **not** run `seed.sql` in production — it is for local development only.
3. **Auth settings** (Dashboard → Authentication → URL Configuration): set the *Site URL* to your deployed URL and add
   `https://your-domain/reset-password` to the redirect URLs. Configure SMTP for real emails, and decide whether to
   require email confirmation (the app handles both).
4. **Host the frontend** on any static host (Vercel, Netlify, Cloudflare Pages…). Set the environment variables
   `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`, build with `npm run build`, publish `dist/`.
   SPA rewrites are included for Vercel (`vercel.json`) and Netlify (`public/_redirects`).

---

## Security model

- **Row Level Security on every table.** Each row carries `user_id` (defaulting to `auth.uid()`); policies only allow
  a user to read and write their own rows. Inserts/updates into property-scoped tables must also reference a property
  the user owns (`owns_property()`), so records can't be attached to someone else's home.
- **Private storage.** Files live in the private `homefolio` bucket under `<user_id>/<property_id>/<area>/…`. Storage
  policies only allow access to paths starting with the user's own id. Files are served via short-lived signed URLs.
  The bucket enforces a 20 MB limit and an allow-list of MIME types; the client validates the same rules first.
- **Database functions run as the caller** (`security invoker`), so RLS still applies to search, dashboard and
  maintenance RPCs. The only `security definer` functions are account deletion (acts only on `auth.uid()`), the
  sign-up profile trigger, and the sample-home generator.
- **No secrets in the frontend.** Only the public URL and anon/publishable key are used, from environment variables.
  Never put the `service_role` key in a `VITE_` variable.
- Deleting a property or account removes stored files first, then database rows cascade.

---

## Sample data

Sample data is kept strictly apart from real data:

- **Local development:** `supabase/seed.sql` creates the demo account and its sample home. It only runs on
  `supabase db reset`.
- **In the app:** new users can choose "explore with a sample home", and anyone can add/remove it in
  *Settings → Your data*. It is a separate property flagged `is_sample`, labelled "Sample" everywhere, and removable in
  one step without touching real homes.

---

## Project structure

```
homefolio/
├── supabase/
│   ├── config.toml                 # local Supabase config
│   ├── migrations/                 # schema, RLS, storage policies, RPCs, sample-home function
│   └── seed.sql                    # local-only demo account
└── src/
    ├── App.tsx                     # routes, providers, auth guards
    ├── index.css                   # Tailwind + design tokens (light/dark)
    ├── context/                    # Auth, active property, custom categories, toasts
    ├── hooks/                      # useQuery (race-safe loader), useEditor, rooms, signed URLs, debounce
    ├── lib/
    │   ├── api.ts                  # CRUD helpers, uploads, property/account deletion
    │   ├── storage.ts              # file validation, image downscaling, signed URLs
    │   ├── fields.ts               # form definitions for every entity
    │   ├── constants.ts            # built-in categories and options
    │   ├── status.ts               # warranty / task / renewal status logic
    │   ├── errors.ts               # human-readable error messages
    │   └── types.ts, format.ts, icons.ts, theme.ts
    ├── components/
    │   ├── ui/                     # Button, Field, Modal, ConfirmDialog, Card, badges, states, layout
    │   ├── forms/                  # schema-driven EntityForm / FormModal, CategorySelect
    │   ├── files/                  # PhotoGallery, DocumentsPanel, document upload/preview modals
    │   ├── layout/                 # AppShell (sidebar + bottom nav), property switcher, nav config
    │   ├── CustomFields.tsx, DetailScaffold.tsx, MeterChart.tsx
    └── pages/                      # one file per screen (+ items/ and maintenance/ shared pieces)
```

### Adding a new field

1. Add a column in a new migration under `supabase/migrations/`.
2. Add it to the type in `src/lib/types.ts`.
3. Add a `FieldDef` in `src/lib/fields.ts` — the form, validation and saving are handled by `EntityForm`.
4. Show it on the relevant detail page's `DetailList`.

---

## Designed for what comes next

- **Document recognition / OCR:** `documents.extracted_text` is already stored and searched. A future Edge Function can
  fill it after upload (e.g. triggered by a storage webhook) without UI changes.
- **Shared households:** `household_members.linked_user_id` is reserved for linking a member to their own login.
  Sharing would add a membership table and extend the RLS policies from "owner" to "owner or member".
- **Mobile app:** the UI is mobile-first with safe-area handling and no browser-only dependencies, so it can be wrapped
  with Capacitor or turned into a PWA.
- **Notifications:** reminder queries live in the `upcoming_reminders` database function, which a scheduled job could
  reuse to send emails or push notifications.
