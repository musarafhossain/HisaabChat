# Technical Requirements Document (TRD)

**Product:** HisaabChat (personal expense tracker)
**Version:** 1.1
**Date:** 2026-10-08 (revised: AdonisJS + MariaDB/MySQL + Flutter)
**Related:** [PRD](01-PRD.md) · [Backend Schema](05-Backend-Schema.md) · [Implementation Plan](06-Implementation-Plan.md)

---

## 1. Architecture Overview

One **Flutter** codebase builds the **Android**, **Windows** and **Web** clients. All three talk to a single **AdonisJS** REST API backed by **MariaDB** (MySQL-compatible). The server is the single source of truth, so the same login shows the same data on every device.

```
┌──────────────────────── Flutter app (one codebase) ────────────────────────┐
│   Android (APK/AAB)        Windows (MSIX / .exe)        Web (static build)   │
│   Riverpod · go_router · dio · freezed · fl_chart · Material 3 (responsive)  │
└───────────────────────────────────┬──────────────────────────────────────────┘
                                    │ HTTPS · JSON · REST /api/v1
                                    │ Authorization: Bearer <access token>
┌───────────────────────────────────▼──────────────────────────────────────────┐
│ Caddy (TLS, reverse proxy)  ── also serves the Flutter Web build (app.domain)│
└───────────────────────────────────┬──────────────────────────────────────────┘
┌───────────────────────────────────▼──────────────────────────────────────────┐
│ AdonisJS 7 API (Node.js 24 LTS)                                               │
│  Router → Middleware (auth, CORS, rate limit) → Controllers                   │
│  → VineJS validators → Services (business logic) → Lucid ORM                  │
│  Ace commands: recurring:run (hourly), balances:check (nightly) via cron      │
└───────────────────────────────────┬──────────────────────────────────────────┘
                           ┌────────▼─────────┐
                           │  MariaDB 11.4 LTS │  (compatible with MySQL 8.4 LTS)
                           └───────────────────┘
```

**Why this stack**
- **Flutter**: one UI codebase for Android, Windows and Web, using Material 3 and adaptive layouts.
- **AdonisJS**: a batteries-included TypeScript framework (ORM, auth, validation, mail, CLI, tests), so there's little glue code to write.
- **MariaDB/MySQL**: a mature transactional database that's easy and cheap to host, with CHECK constraints, foreign keys and good aggregate performance.

## 2. Technology Stack

### 2.1 Backend
| Concern | Choice | Notes |
|---|---|---|
| Runtime | Node.js 24 LTS | AdonisJS 7 requires Node ≥ 24 |
| Framework | **AdonisJS 7** (API starter kit) | `npx create-adonisjs@latest backend --kit=api`, then switched from SQLite to `mysql2` |
| Model columns | Lucid **schema generation** | `database/schema.ts` is regenerated from the DB after each migration; `database/schema_rules.ts` maps BIGINT → `@moneyColumn()` (number) and TINYINT(1) → `@boolColumn()` |
| TS compiler (dev) | `@poppinss/ts-exec` + `@swc/core` **pinned to 1.16.2** via `overrides` | Newer SWC rejects its native cache on Windows profiles writable by other accounts (see the root README) |
| Language | TypeScript (strict) | |
| ORM / migrations | **Lucid** (Knex-based), `mysql2` driver | |
| Validation | **VineJS** | Validators in `app/validators` |
| Auth | `@adonisjs/auth` **access tokens** guard | Opaque tokens, hashed in the `auth_access_tokens` table |
| Password hashing | `@adonisjs/hash` (scrypt default, or argon2) | |
| Rate limiting | `@adonisjs/limiter` | Login, register, password reset |
| CORS | `@adonisjs/cors` | Allow the web app origin |
| Mail | `@adonisjs/mail` (SMTP / Resend / Brevo) | Password reset |
| Scheduled jobs | Ace commands triggered by system cron (or the `adonisjs-scheduler` package) | |
| Dates | Luxon (built into Lucid) | |
| IDs | UUID v7 (`uuid` package) | Time-ordered, good index locality |
| Testing | **Japa** (+ `@japa/api-client`, `@japa/assert`) | |
| Logging | Pino (built in) | |

### 2.2 Database
| Item | Choice |
|---|---|
| Primary target | **MariaDB 11.4 LTS** |
| Also supported | **MySQL 8.4 LTS** (CI runs both) |
| Engine / charset | InnoDB · `utf8mb4` / `utf8mb4_unicode_ci` |
| Time zone | All `DATETIME` values stored in **UTC**; connection `timezone: 'Z'` |

### 2.3 Frontend (Flutter)
| Concern | Package | Notes |
|---|---|---|
| SDK | Flutter 3.x stable, Dart 3 | Pin the exact version in `.fvmrc` / CI |
| State management | `flutter_riverpod` 3 (hand-written `Provider` / `Notifier` / `FutureProvider`) | `riverpod_generator` currently needs a newer `meta` than Flutter 3.41 ships |
| Routing | `go_router` | Deep links and web URLs; `usePathUrlStrategy()` on web |
| HTTP | `dio` | Interceptors for auth, errors and retry |
| Models | `freezed` + `json_serializable` | Immutable DTOs |
| Token storage | `flutter_secure_storage` | Android Keystore, Windows Credential Manager; on web, browser storage (see §3.8) |
| Preferences | `shared_preferences` | Last-used account, theme cache |
| Charts | `fl_chart` | Donut, bar and line charts |
| i18n / format | `intl` | `NumberFormat.currency(locale: 'en_IN', symbol: '₹')` |
| Icons | Material Symbols **Rounded** subset bundled in `assets/fonts` (~184 KB, variable font) | Generated by `tool/icons/generate_icons.py` from `tool/icons/icons.txt`; string keys in the DB mapped via `AppIcons`; animated `fill` axis. Replaces the `material_symbols_icons` package, whose 35 MB of fonts made debug web builds take minutes to show the first frame |
| Animation | Flutter implicit/explicit animations, **`animations`** (container transform, shared axis, fade-through), **`flutter_animate`** | Motion tokens in `core/motion`; respects reduce-motion |
| Desktop window | `window_manager` | Minimum size, title (Windows) |
| File export | `file_saver` / `share_plus` | Web download, Windows Save dialog, Android share sheet |
| Packaging | `flutter_launcher_icons`, `flutter_native_splash`, `msix` | |
| Testing | `flutter_test`, `integration_test`, `mocktail` | Golden tests at 3 window sizes |
| Lint | `flutter_lints` / `very_good_analysis` | |

### 2.4 Infrastructure
| Item | Choice |
|---|---|
| Local dev | `docker compose` running MariaDB (+ Adminer) |
| Production | One small VPS (e.g. Hetzner / DigitalOcean, ~$5/mo), Docker Compose: `caddy` + `api` + `mariadb` |
| Backups | Nightly `mariadb-dump` to object storage, 14-day retention |
| CI | GitHub Actions: backend tests (MariaDB + MySQL services), `flutter analyze/test`, builds for web, Android and Windows (Windows runner) |

## 3. Core Technical Decisions

### 3.1 Money representation
- All amounts are stored as **signed `BIGINT` in minor units (paise)**: `₹1,250.50 → 125050`. Floating point is never used for money.
- Transaction `amount` is always **> 0**. The direction comes from `type`. Only account balances can be negative.
- **Backend:** `mysql2` returns `SUM()` results as `DECIMAL` strings. Set `decimalNumbers: true` on the connection, or cast with `Number()` in a single `toDTO` layer. Values stay well under 2⁵³, so JS `number` is safe.
- **Flutter:** amounts are Dart `int` (paise). Web compiles `int` to a JS number, which is also safe below 2⁵³. Use a `Money` helper for parsing input (`"1,250.5"` → `125050`), formatting (`₹1,25,050`) and compact display (`₹1.2L`).

### 3.2 Account balances
- `accounts.balance` is a **cached** column, updated in the **same DB transaction** as any transaction create, update or delete.

| Type | `account_id` | `to_account_id` |
|---|---|---|
| INCOME | `+amount` | — |
| EXPENSE | `−amount` | — |
| TRANSFER | `−amount` | `+amount` |
| ADJUSTMENT | `+amount` if INCREASE, `−amount` if DECREASE | — |
| LEND *(v1.0)* | `−amount` | — (person owes you more) |
| BORROW *(v1.0)* | `+amount` | — (you owe the person more) |
| COLLECT *(v1.0)* | `+amount` | — (person owes you less) |
| REPAY *(v1.0)* | `−amount` | — (you owe the person less) |

Lend/borrow types carry a `person_id`. Like transfers, they are never income or expense and never count toward budgets. A person's balance = Σ LEND + Σ REPAY − Σ BORROW − Σ COLLECT (positive = they owe you).

- **Update** = reverse the old effects, then apply the new ones. **Delete** = reverse the old effects.
- Inside `db.transaction(async (trx) => …)`: lock the transaction row with `.forUpdate()` and change balances with atomic `UPDATE accounts SET balance = balance + ?` (Lucid `.increment()`).
- **Source of truth:** `opening_balance + Σ effects`. The `balances:check` Ace command runs nightly, reports any drift and can fix it with `--fix`.

### 3.3 Budgets
- A budget = name + default monthly amount + **one or more categories**.
- **Exclusivity is enforced by the data model:** `categories.budget_id` is a nullable FK, so a category can belong to at most one budget. MySQL and MariaDB have no partial indexes, and this design doesn't need them.
- Sub-categories inherit their parent's budget unless they set their own: `effective_budget = COALESCE(child.budget_id, parent.budget_id)`.
- **Spent** = `SUM(amount)` of EXPENSE transactions whose category maps to the budget, with `date` within the period.
- **Overrides:** `budget_period_overrides` sets a different amount for one period (e.g. Education ₹15,000 in a fees month).
- **Rollover** (optional): `effective(m) = amount(m) + (effective(m−1) − spent(m−1))`, computed on read with at most 12 months of look-back.
- **Status:** `< alert_percent` → OK, `≥ alert_percent` → WARNING, `> 100%` → EXCEEDED.
- **Safe to spend per day** (VARIABLE budgets only) = `max(remaining, 0) / days left in period`.
- Archiving a budget unlinks its categories (`budget_id = NULL`). Past months always use the **current** mapping, and this is documented behavior.

### 3.4 Periods & time zones
- `transactions.date` is `DATETIME(3)` in UTC. The client sends ISO-8601 with an offset, and the server normalizes it to UTC.
- `users.timezone` (IANA, default `Asia/Kolkata`) and `users.month_start_day` (1–28) define periods. The **server** computes period bounds with Luxon (`DateTime.now().setZone(tz)`) and returns `periodStart` / `periodEnd`, so all three clients agree.
- The month parameter in the API is `YYYY-MM` and means "the period that starts in that month".

### 3.5 Recurring transactions
- `recurring_rules` stores the template (type, amount, accounts, category, note), the schedule (`frequency`, `interval`, `day_of_month`, start and end dates) and `next_run_at`.
- The Ace command `node ace recurring:run` runs **hourly** from cron. For each active rule with `next_run_at <= now`:
  - `auto_create = true` → create the transaction (balance logic as usual) and advance `next_run_at`.
  - `auto_create = false` → insert a `recurring_occurrences` row with status PENDING. The user confirms or skips it in the app.
- **Idempotency:** a unique key on `(recurring_rule_id, occurrence_date)` in `transactions` and on `(recurring_rule_id, due_date)` in occurrences.
- Monthly rules on day 29–31 are clamped to the last day of shorter months.

### 3.6 IDs & idempotent creates
- Primary keys are **UUID v7** stored as `CHAR(36)`, which works on both MariaDB and MySQL. MariaDB's native `UUID` type isn't used, for compatibility.
- The Flutter client **generates the `id`** for new transactions. If a request is retried after a timeout, the server sees the existing id and returns the existing record (`200`) instead of creating a duplicate. This also prepares for offline sync later.

### 3.7 Deletion strategy
- Accounts, categories and budgets are **archived** (`archived_at`) rather than deleted while they're referenced.
- Transactions are hard-deleted (with balance reversal). The client offers **Undo** for 5 s by re-creating the transaction with the same id.
- Deleting a user account is done by a service that deletes rows in dependency order inside one DB transaction. It doesn't rely on multi-path cascades.

### 3.8 Authentication
- `POST /auth/login` returns an **opaque access token** (`oat_…`). Only its hash is stored. Expiry is 30 days, and it's refreshed on use (a new token is issued when less than 7 days remain).
- The client stores the token with `flutter_secure_storage` and sends `Authorization: Bearer …`.
- **Web caveat:** browser storage can be read by any script running on the page, so the web build ships a strict CSP (no third-party scripts) to reduce XSS risk. httpOnly cookie sessions for web are a P2 option.
- Logout revokes the current token. "Log out of all devices" revokes all of the user's tokens.
- Google Sign-In is P2. `google_sign_in` doesn't support Windows, so it would need an OAuth browser flow there.

### 3.9 MariaDB / MySQL compatibility rules
Write SQL that runs on both databases:
- No `RETURNING`, no native `UUID` type, no partial or functional indexes, no MariaDB-only JSON functions.
- CHECK constraints are allowed: they're enforced on MySQL ≥ 8.0.16 and MariaDB ≥ 10.2.
- Use `DATETIME(3)` rather than `TIMESTAMP` (MariaDB 10.4 rejects a second `TIMESTAMP NOT NULL` column without a default).
- Local development runs on **XAMPP MariaDB 10.4**; CI also runs the suite on MariaDB 11.4 and MySQL 8.4.
- MySQL forbids `ON DELETE CASCADE/SET NULL` on columns used in a CHECK. FKs on those columns (`account_id`, `to_account_id`, `category_id`) therefore use the default RESTRICT.
- CTEs and window functions are fine on both.

## 4. API Surface

### 4.1 Conventions
- Base URL `https://api.<domain>/api/v1`. JSON keys are **camelCase**; DB columns are snake_case (Lucid's naming strategy maps them).
- Success: `{ "data": …, "meta": { … } }` (meta only for paginated lists).
- Validation error: `422 { "errors": [{ "field": "amount", "rule": "positive", "message": "…" }] }` (VineJS default).
- Other errors: `400/401/403/404/409/429 { "errors": [{ "message": "…", "code": "E_…" }] }`.
- Pagination: cursor-based. `?limit=30&cursor=<opaque>`, with `meta.nextCursor` returned.
- Every query is scoped to `auth.user.id`. Accessing another user's resource returns **404**.

### 4.2 Endpoints
| Method & path | Purpose |
|---|---|
| **Auth** | |
| `POST /auth/register` | `{fullName, email, password}` → user + token; seeds default categories |
| `POST /auth/login` | `{email, password}` → token |
| `POST /auth/logout` | Revoke current token |
| `POST /auth/logout-all` | Revoke all tokens |
| `POST /auth/forgot-password` / `POST /auth/reset-password` | Email reset flow |
| `GET /me` · `PATCH /me` | Profile & preferences (currency, timezone, monthStartDay, theme) |
| `POST /me/onboarding/complete` | Sets `onboardedAt` |
| `DELETE /me` | Delete account and all data (requires password) |
| **Accounts** | |
| `GET /accounts?includeArchived=` | List + `meta.netWorth` |
| `POST /accounts` · `GET/PATCH/DELETE /accounts/:id` | DELETE → 409 if it has transactions |
| `POST /accounts/:id/archive` · `/unarchive` | |
| `POST /accounts/:id/reconcile` | `{actualBalance}` → creates an ADJUSTMENT |
| **Categories** | |
| `GET /categories?type=` · `POST /categories` | |
| `PATCH /categories/:id` · `POST /categories/:id/archive` | |
| `PUT /categories/order` | `{ids: [...]}` |
| **Transactions** | |
| `GET /transactions` | `from, to, type, accountId, categoryId, q, cursor, limit` → list + `meta.totals` |
| `POST /transactions` | Idempotent by client-supplied `id`; response includes `budgetAlerts[]` |
| `GET/PATCH/DELETE /transactions/:id` | |
| **Budgets** | |
| `GET /budgets?month=YYYY-MM` | Status for every active budget + summary + unbudgeted spending |
| `POST /budgets` · `PATCH /budgets/:id` | Body includes `categoryIds[]`; 409 if a category is taken |
| `GET /budgets/:id?month=` | Detail, contributing transactions, 6-month history |
| `POST /budgets/:id/archive` | |
| `PUT /budgets/:id/overrides/:month` · `DELETE …` | One-month amount override |
| **Recurring** | |
| `GET/POST /recurring` · `PATCH/DELETE /recurring/:id` | |
| `GET /recurring/upcoming?days=7` | |
| `GET /recurring/occurrences?status=PENDING` | |
| `POST /recurring/occurrences/:id/confirm` | Optional body to adjust amount/date |
| `POST /recurring/occurrences/:id/skip` | |
| **People: lend & borrow (v1.0)** | |
| `GET /people` · `POST /people` | List with `balance` (positive = they owe you) + `meta.totals {toReceive, toPay}` |
| `GET/PATCH /people/:id` · `POST /people/:id/archive` | |
| `GET /transactions?personId=` | The person's thread |
| `POST /people/:id/settle` | Creates the COLLECT/REPAY that brings the balance to zero |
| `POST /people/:id/write-off` | Forgive: turns the remaining balance into an EXPENSE (they owed you) or INCOME (you owed them) |
| **Dashboard & reports** | |
| `GET /dashboard?month=` | Net worth, month totals, top budgets, upcoming, pending, recent |
| `GET /reports/by-category?from&to&type` | Totals and % per category |
| `GET /reports/trend?months=6` | Monthly income, expense, net |
| `GET /export/transactions.csv?from&to` · `GET /export/all.json` | Downloads |
| `GET /health` | Liveness + DB check |

### 4.3 Example: create a transaction
```http
POST /api/v1/transactions
Authorization: Bearer oat_xxx
Content-Type: application/json

{ "id": "0192f1d2-7c1a-7b3e-9a1e-2f6c1d0a9b11",
  "type": "EXPENSE", "amount": 54000,
  "accountId": "…", "categoryId": "…",
  "date": "2026-10-08T19:45:00+05:30", "note": "Big Bazaar" }
```
```json
201 { "data": { "id": "0192f1d2-…", "type": "EXPENSE", "amount": 54000, "date": "2026-10-08T14:15:00.000Z",
                "account": { "id": "…", "name": "Cash", "icon": "wallet" },
                "category": { "id": "…", "name": "Food & Groceries", "icon": "shopping_cart", "color": "#10B981" },
                "note": "Big Bazaar", "toAccount": null, "isRecurring": false },
      "budgetAlerts": [ { "budgetId": "…", "name": "Food & Groceries", "percent": 85, "status": "WARNING" } ] }
```

```ts
// backend/app/validators/transaction.ts
import vine from '@vinejs/vine'

export const createTransactionValidator = vine.compile(
  vine.object({
    id: vine.string().uuid().optional(),
    type: vine.enum(['INCOME', 'EXPENSE', 'TRANSFER']),
    amount: vine.number().withoutDecimals().positive().max(10_000_000_000_00),
    accountId: vine.string().uuid(),
    toAccountId: vine.string().uuid().optional().requiredWhen('type', '=', 'TRANSFER'),
    categoryId: vine.string().uuid().optional().requiredWhen('type', 'in', ['INCOME', 'EXPENSE']),
    date: vine.date({ formats: { utc: true } }),
    note: vine.string().trim().maxLength(200).optional(),
  })
)
// Service additionally checks: accountId !== toAccountId; the account and category belong
// to the user and aren't archived; the category type matches the transaction type.
```

## 5. Flutter App Architecture

### 5.1 Layers (feature-first)
```
presentation (widgets, screens)  →  providers (Riverpod Notifiers)  →  repositories  →  ApiClient (dio)
```
- **Repositories** wrap the endpoints and return freezed models. A `Result`/exception type maps API errors (422 → field errors on forms).
- **Providers:** `AsyncNotifier` per screen or collection. After a mutation, the relevant providers are invalidated (transactions, accounts, budgets, dashboard) so balances and budgets refresh everywhere.
- **Optimistic UI** on transaction create/delete, rolled back on error.

### 5.2 Routing (go_router)
`/login`, `/register`, `/forgot-password`, `/onboarding`, then inside a `StatefulShellRoute` (keeps each tab's state): `/dashboard`, `/transactions`, `/budgets`, `/budgets/:id`, `/accounts`, `/accounts/:id`, `/reports`, `/settings/...`.
A redirect guard checks for a stored token and `onboardedAt`. On web, the browser back button and URLs work with the path URL strategy.

### 5.3 Responsive & adaptive layout
The UI follows a **WhatsApp-inspired** layout (see the [Design Brief](04-UI-UX-Design-Brief.md)).

| Window class (width) | Navigation | Full transaction form | Lists & details |
|---|---|---|---|
| **Compact** < 600 dp (phones) | App bar (🔍 ⋮) + bottom `NavigationBar` (Home, Transactions, Budgets, Accounts) + green FAB | Full-screen page | Single pane; threads and info pages push |
| **Medium** 600–839 dp | 64 dp icon rail | Dialog (520 dp) | Single pane |
| **Expanded** ≥ 840 dp (desktop, web) | Icon rail (WhatsApp Desktop style) | Slide-in over the list panel | **Three columns:** rail + list panel (360–420 dp) + detail pane (thread / info / form) |

A single `AppShell` widget picks the layout with `LayoutBuilder`/`MediaQuery.sizeOf`.

**Account thread & quick-add composer:** `ThreadView` is a reversed `ListView` over `GET /transactions?accountId=…` (cursor pagination loading older entries upward). `QuickEntryParser` is a pure Dart function (amount with simple math, category matching on names and aliases, remaining text → note) with unit tests. Sends are optimistic: the bubble shows 🕒 until the API returns 201/200, then ✓, or ⚠ with retry. The client-generated UUID makes retries safe. Window class is decided by width, not by platform, so resizing the Windows or browser window switches layouts.

### 5.4 Platform specifics
| Platform | Details |
|---|---|
| **Android** | minSdk 24 (Android 7.0); edge-to-edge; predictive back; haptic feedback on save; swipe-to-delete rows; share sheet for exports |
| **Windows** | Windows 10/11 x64; `window_manager` minimum size 400×640; keyboard shortcuts (Ctrl+N new, Ctrl+F search, Esc close, Enter save); hover states; right-click context menu on rows; visible scrollbars; MSIX package |
| **Web** | Chrome/Edge/Firefox/Safari (last 2 versions); path URLs; page titles per route; CSV download via browser; loading splash in `index.html` while the engine starts |

### 5.5 Networking
- `dio` base URL comes from `--dart-define=API_BASE_URL=…`.
- Interceptors: attach the token; on **401**, clear the token and redirect to `/login`; retry idempotent requests once on network errors; map errors.
- Connectivity: show a "You're offline" banner, keep form data and allow retry. Full offline mode is P2 (drift/SQLite queue with client UUIDs).

## 6. Repository Structure (monorepo)
```
hisaabchat/
├─ backend/                         # AdonisJS 7
│  ├─ app/
│  │  ├─ controllers/               # thin: validate → service → serialize
│  │  ├─ services/                  # accounts, transactions, balance, budgets, periods, reports, recurring, user_defaults
│  │  ├─ models/                    # Lucid models
│  │  ├─ validators/                # VineJS
│  │  ├─ middleware/
│  │  ├─ transformers/              # toDTO helpers
│  │  └─ exceptions/handler.ts
│  ├─ commands/                     # recurring_run.ts, balances_check.ts
│  ├─ database/migrations, seeders/
│  ├─ start/routes.ts, kernel.ts, env.ts
│  ├─ config/
│  └─ tests/unit, functional
├─ app/                             # Flutter
│  ├─ lib/
│  │  ├─ main.dart
│  │  ├─ app/                       # router, theme (WhatsApp-style), AppShell, shortcuts
│  │  ├─ core/                      # api_client, money, dates, icons registry, storage, errors, widgets
│  │  └─ features/
│  │     ├─ auth/  onboarding/  dashboard/  transactions/  accounts/
│  │     ├─ categories/  budgets/  recurring/  reports/  settings/
│  │     └─ <feature>/{data, providers, presentation}
│  ├─ test/  integration_test/
│  ├─ android/  windows/  web/
│  └─ pubspec.yaml
├─ deploy/                          # docker-compose.prod.yml, Caddyfile, backup script
├─ docker-compose.yml               # local MariaDB + Adminer
├─ .github/workflows/
└─ docs/
```

## 7. Non-Functional Requirements

| Area | Requirement |
|---|---|
| **Security** | HTTPS only; hashed passwords; hashed opaque tokens with expiry; rate-limited auth (5/min/IP+email); CORS restricted to the web origin; all queries scoped by `user_id`; security headers via Caddy (HSTS, CSP for the web app); secrets in env vars only |
| **Data integrity** | Balance changes only inside DB transactions; FKs, CHECK constraints; nightly balance check |
| **Performance** | API p95 < 200 ms for list/dashboard with 10k transactions; indexes per [schema](05-Backend-Schema.md); cursor pagination (30/page). App: 60 fps scrolling; Android cold start < 2 s on a mid-range phone; web first load < 4 s on 4G (CanvasKit cached afterward) |
| **Availability** | Best effort; daily DB backups with a tested restore |
| **Accessibility** | WCAG 2.1 AA intent: `Semantics` labels, contrast ≥ 4.5:1, touch targets ≥ 48 dp, keyboard navigation and focus on Windows/Web, text scaling to 200% |
| **Responsiveness** | 360 dp phone up to 1920 px desktop; verified with golden tests at 390×844, 800×1000 and 1440×900 |
| **Privacy** | No third-party trackers; full export and account deletion |

## 8. Configuration & Environments

**Backend `.env`**
```
NODE_ENV=development
PORT=3333
HOST=0.0.0.0
APP_KEY=...
LOG_LEVEL=info
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=expense
DB_PASSWORD=...
DB_DATABASE=hisaabchat
CORS_ORIGINS=http://localhost:5000,https://app.example.com
SMTP_HOST=... SMTP_PORT=... SMTP_USERNAME=... SMTP_PASSWORD=...
APP_WEB_URL=https://app.example.com
```

**Flutter**: `--dart-define=API_BASE_URL=...`
| Target | Local dev URL |
|---|---|
| Web (`flutter run -d chrome --web-port 5000`) | `http://localhost:3333/api/v1` |
| Windows (`flutter run -d windows`) | `http://localhost:3333/api/v1` |
| Android emulator | `http://10.0.2.2:3333/api/v1` (allow cleartext in a debug-only network config) |
| Android physical device | `http://<PC LAN IP>:3333/api/v1` |

Environments: `local` → `staging` (optional) → `production`.

## 9. Testing Strategy
| Level | Scope | Tooling |
|---|---|---|
| Backend unit | Money, period bounds (TZ + month start day), balance effects, budget math (rollover, safe-to-spend), recurring date calculation | Japa |
| Backend functional | Each endpoint against a real MariaDB test DB (transactions rolled back per test): balance invariant across create/update/delete/transfer; category exclusivity (409); user isolation (404); idempotent create | Japa + api-client |
| Flutter unit | `Money` parse/format, repositories (mocked dio), notifiers | flutter_test, mocktail |
| Flutter widget/golden | Key screens at compact/medium/expanded sizes, light & dark | flutter_test goldens |
| Flutter integration | Sign up → onboarding → add expense → budget updates; transfer; delete + undo | `integration_test` on Android emulator, Windows and Chrome |
| CI | Backend tests on MariaDB 11.4 **and** MySQL 8.4 services; `flutter analyze`, `flutter test`; build artifacts for web, APK and Windows | GitHub Actions |

**Critical invariants**
1. For every account: `balance == opening_balance + Σ effects`.
2. Transfers never change net worth (when both accounts are included in totals).
3. Budget `spent` equals the sum of qualifying expenses in the period, with each expense counted at most once.
4. User A can never read or modify user B's data.

## 10. Build & Deployment
| Artifact | Command | Distribution |
|---|---|---|
| API | `node ace build` → Docker image (node:24-alpine) | VPS via Docker Compose; `node ace migration:run --force` on deploy |
| Web | `flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=…` | Static files served by Caddy at `app.<domain>` with an SPA fallback (`try_files {path} /index.html`) so deep links like `/accounts` work; CanvasKit is self-hosted instead of loaded from gstatic.com |
| Android | `flutter build appbundle` / `flutter build apk --split-per-abi` | Signed APK (sideload) for personal use; AAB for Play Store later |
| Windows | `flutter build windows` + `dart run msix:create` | MSIX installer (self-signed for personal use) or a zip of the `Release` folder |

Cron (on the host or in an `api` sidecar):
```
0 * * * *   docker compose exec -T api node ace recurring:run
30 2 * * *  docker compose exec -T api node ace balances:check
0 3 * * *   /opt/hisaabchat/backup.sh
```

## 11. Risks & Mitigations
| Risk | Mitigation |
|---|---|
| Balance drift from bugs | Atomic updates, functional tests on the invariant, nightly `balances:check` |
| Time zone off-by-one at month edges | Server-only period math in `PeriodService`; tests for 23:30 IST and month-start-day cases |
| `BIGINT`/`DECIMAL` returned as strings by mysql2 | `decimalNumbers: true` + a single `toDTO` layer + tests on JSON types |
| MariaDB vs MySQL differences | Compatibility rules (§3.9); CI against both |
| Flutter Web first-load size | Loading splash, caching, `--wasm` build where supported; the web is the secondary platform |
| Token in web storage (XSS) | No third-party scripts, strict CSP, short-lived tokens; cookie sessions are a P2 option |
| Windows code-signing cost | Self-signed MSIX for personal use; certificate only if distributing publicly |
