# Implementation Plan

**Product:** HisaabChat (personal expense tracker)
**Date:** 2026-10-08 (revised: AdonisJS + MariaDB/MySQL + Flutter for Android, Windows, Web)
**Related:** [PRD](01-PRD.md) · [TRD](02-TRD.md) · [Backend Schema](05-Backend-Schema.md)

---

## 1. Approach
- **Monorepo:** `backend/` (AdonisJS), `app/` (Flutter), `deploy/`, `docs/`.
- **Vertical slices:** each phase ships a feature end to end (migration → service → API → Flutter screen → tests) and is checked on **all three targets** (Android emulator, Windows, Chrome).
- The MVP (all P0) comes first, then v1.0 (P1).
- Estimates assume one developer working part-time (~10–15 h/week). 1 "day" ≈ 3–4 focused hours.

## 2. Timeline Overview

| Phase | Name | Est. | Milestone |
|---|---|---|---|
| 0 | Monorepo, tooling & foundations | 3 days | API + Flutter app run locally on Android, Windows, Web |
| 1 | Auth, profile & responsive app shell | 4 days | Register / log in on all 3 platforms |
| 2 | Accounts | 3 days | Create accounts, see net worth |
| 3 | Categories & transactions | 6 days | Log income/expense/transfer; balances correct |
| 4 | Budgets | 5 days | Multi-category budgets with progress |
| 5 | Dashboard, onboarding & reports | 5 days | **🚀 MVP (v0.1)** |
| 6 | Recurring, rollover, alerts, trends, **lend & borrow** | 8 days | |
| 7 | Platform polish & packaging | 4 days | APK, MSIX and hosted web build |
| 8 | Production deploy & hardening | 3 days | **🚀 v1.0** |
| | **Total** | **~41 days (≈ 10–13 weeks part-time)** | |

## 3. Phases in Detail

### Phase 0 — Monorepo, Tooling & Foundations
**Repo & infrastructure**
- [x] `git init`, `.gitignore` (Node + Flutter), README, `.editorconfig`.
- [x] `docker-compose.yml`: `mariadb:11.4` (volume, utf8mb4, port 3306) + `adminer` (optional; local dev uses XAMPP MariaDB 10.4).

**Backend**
- [x] `npx create-adonisjs@latest backend --kit=api` (AdonisJS 7, Node 24); switched SQLite → `mysql2`; pinned `@swc/core` 1.16.2.
- [x] Configure `config/database.ts` (`timezone: 'Z'`, `decimalNumbers: true`, utf8mb4) and `start/env.ts` validation.
- [x] Add packages: `mysql2`, `uuid` (CORS ships with the starter). *`@adonisjs/limiter` and `@adonisjs/mail` move to Phase 1 with the auth work.*
- [x] Write **all migrations** from [Backend Schema](05-Backend-Schema.md), including the CHECK constraints via `schema.raw`; run them on MariaDB (MySQL runs in CI).
- [x] Models for every table (UUID v7, `selfAssignPrimaryKey`, money via `@moneyColumn()`, booleans via `@boolColumn()` from schema rules).
- [x] `app/services/money.ts`, `period_service.ts` (period bounds in the user's TZ + month start day) **with Japa unit tests**.
- [x] Consistent `{ data }` / `{ errors: [...] }` JSON (starter serializer + handler). `GET /api/v1/health`.
- [x] Functional tests: health, signup/login/profile, and DB-level constraint checks.

**Flutter**
- [x] `flutter create app --org com.hisaabchat --project-name hisaabchat --platforms=android,windows,web` (package ID `com.hisaabchat.hisaabchat`; display name **HisaabChat** on Android, Windows (MSIX `display_name`) and Web (`manifest.json`, `<title>`)).
- [x] Add packages: flutter_riverpod (hand-written providers), go_router, dio, freezed, json_serializable, flutter_secure_storage, shared_preferences, intl, fl_chart, animations, flutter_animate, window_manager, build_runner, very_good_analysis.
- [x] `core/`: `ApiClient` (dio + `API_BASE_URL` dart-define), `Money` (parse/format/compact, **unit tested**), `AppIcons` registry (string key → `Symbols.*`, Rounded), error model.
- [x] `core/motion/`: duration and curve tokens, `AppPageTransitions` (shared axis, fade-through, container transform), `AnimatedAmount`, `RingProgress`, `FadeSlideIn`, `PopIn`, `Shake`, `MorphIconButton`, `AnimatedFillIcon`, and a reduce-motion helper.
- [x] Theme: **WhatsApp-inspired** light/dark `ColorScheme` + `AppColors` ThemeExtension (bubbles, thread wallpaper, finance colors) and component themes (app bar, nav bar, chips, list tiles, FAB) per the [Design Brief](04-UI-UX-Design-Brief.md); platform system fonts.
- [x] Connection-check screen calling `/health` (+ design preview of rings, counters, icons). Release builds verified for Web and Windows; Android debug APK built.

**CI (GitHub Actions)**
- [x] `backend.yml`: lint, typecheck, Japa tests against **MariaDB 11.4 and MySQL 8.4** service containers (matrix).
- [x] `app.yml`: `flutter analyze`, `flutter test`; build web + APK (ubuntu) and Windows (windows-latest).

**Done when:** all three targets talk to the local API, and CI is green.

### Phase 1 — Auth, Profile & Responsive Shell
**Backend**
- [x] `User` model with `withAuthFinder` + `DbAccessTokensProvider` (30-day expiry, `oat_` prefix, token named after the device).
- [x] `POST /auth/register` (VineJS; unique email; optional device time zone) → creates the user + **`UserDefaultsService.seed`** (default categories) in one DB transaction → returns a token.
- [x] `POST /auth/login`, `/auth/logout`, `/auth/logout-all`; `GET/PATCH /me`; `POST /me/onboarding/complete`.
- [x] Rate limits on register and login (`@adonisjs/limiter`, database store: 10/min per IP, then a 5-minute block).
- [ ] Forgot/reset password with `@adonisjs/mail` → **deferred to Phase 7**.
- [x] Functional tests (42 total): register + 22 seeded categories, validation, login, logout vs logout-all, profile updates and validation, onboarding.

**Flutter**
- [x] `AuthRepository`, `authControllerProvider`, token in `flutter_secure_storage`, dio auth + 401 interceptors (401 → signed out everywhere).
- [x] Splash (with retry when the API is unreachable), Welcome, Login and Register screens (centered ≤ 420 dp on wide screens). *Forgot password moves to Phase 7 with the mail setup.*
- [x] go_router with a redirect guard and `StatefulShellRoute` (six sections; settings sub-pages open full screen).
- [x] **`AppShell`** (WhatsApp-style): green-title app bar with 🔍 ⋮ + bottom `NavigationBar` (Home, Transactions, Budgets, Accounts) + FAB on compact; icon rail on medium; **rail + list panel + detail pane** on expanded, with an empty-pane placeholder. Placeholder screens for each tab.
- [x] Base widgets: `ChatTile`, `IconAvatar`, `SearchPill`, `FilterChipsRow`, `CountBadge`, `SettingsTile`, `EmptyState`, `EmptyDetailPane`, `ListDetailLayout`, `AppLogo`; Welcome screen.
- [x] Icon font subset (`tool/icons/generate_icons.py`): 93 icons, 184 KB instead of ~35 MB, so debug web starts quickly.
- [x] Settings (WhatsApp-style profile header) → Account (name, time zone, month start day; currency fixed to ₹ for now), Appearance (theme synced to the profile, Reduce motion), Connection, Log out, Log out of all devices.
- [x] Windows: `window_manager` minimum size + title; Ctrl+1…5 switch sections. Web: `usePathUrlStrategy()`.
- [x] Widget tests (21 total): auth flows, saved/expired sessions, offline splash retry, logout, phone vs desktop shell, theme sync.

**Done when:** sign up and log in work on Android, Windows and Web, the shell adapts as the window is resized, and default categories exist in the DB.

### Phase 2 — Accounts
- [x] **API:** `AccountService` (create sets `balance = opening_balance`; update shifts the balance when the opening balance changes, with the row locked; archive/unarchive; delete → 409 `E_ACCOUNT_IN_USE` if it has transactions), list with `meta.netWorth`. Type defaults for icon and color; duplicate names → 422 on `name`.
- [x] Exception handler: every error is `{ errors: [{ message, code?, field? }] }` (no stack-trace dumps for 404/409).
- [x] Functional tests (55 total): CRUD, credit cards, net worth with `include_in_total` and archived, opening-balance edits, validation, delete rules, 404 for another user's account, error format.
- [x] **Flutter:** `AccountsRepository` + `accountsProvider`; `/accounts` as a **chat-style list** (total balance card, search, type chips, tiles with balance or card outstanding, archived section, pull to refresh; last-transaction preview added in Phase 3). Home shows the total balance.
- [x] Add/Edit account form (bottom sheet on compact, dialog otherwise): type chips, name, balance or card outstanding (`AmountField`, accepts `120+80`), credit limit, 12-color palette, include in total. Icon follows the type.
- [x] Account info page (contact-info style: avatar Hero, balance, stat tiles, edit, archive, delete): full screen at `/accounts/:id` on phones, in the detail pane on desktop. The chat-style thread replaces its placeholder in Phase 3.
- [x] Widget tests (28 total): add first account, credit card outstanding, duplicate name, search and chips, archive, delete conflict on desktop, Home total.

**Done when:** Cash, Bank and UPI accounts can be added and net worth is correct on all three platforms.

### Phase 3 — Categories & Transactions *(core; get this right)*
**Backend**
- [ ] `BalanceService` (`effectsOf`, `negate`, `applyEffects`) per the schema doc.
- [ ] `TransactionService` create/update/delete inside `db.transaction` with `forUpdate()`, ownership and type checks, and **idempotent create by client id**.
- [ ] `GET /transactions`: filters, search (`note LIKE` / category name), cursor pagination on `(date, id)`, `meta.totals`.
- [ ] Categories API: list, create, update, archive, reorder.
- [ ] `POST /accounts/:id/reconcile` → ADJUSTMENT.
- [ ] **Functional tests for the balance invariant:** every type; editing amount, account and type (Expense → Transfer); delete; repeated POST with the same id.

**Flutter**
- [ ] Widgets: `AmountField` (large, numeric keypad, supports `120+80`), `TxnTypeSegmentedButton`, `CategoryChipPicker` + full `CategoryGridSheet`, `AccountPicker`, `DateTimeField`.
- [ ] **Add/Edit Transaction** form, available globally (FAB, rail button, Ctrl+N). Generates a UUID v7 for new records. Remembers the last-used account.
- [ ] `/transactions`: chat-list tiles, day headers with totals, infinite scroll, search pill, filter chips (All/Expense/Income/Transfer/month), more filters in ⋮. Expanded: tile selection opens the form in the detail pane.
- [ ] Delete: confirm → optimistic remove → SnackBar **Undo** (re-POST with the same id). Swipe-to-delete on Android; right-click menu on Windows/Web.
- [ ] Settings → Categories (tabs Expense/Income; add, edit, archive, drag to reorder).
- [ ] **Account thread:** `ThreadView` (reversed list, `DoodleWallpaper`, `DateChip`, `SystemChip`, `TxnBubble` with in/out sides and 🕒/✓/⚠ status, jump-to-latest).
- [ ] **Quick-add composer:** `QuickEntryParser` (**unit tested**: amounts, math, category aliases, notes) + `QuickComposer` (± toggle, suggestion chips, 📎 → full form, ➤/Enter to send; optimistic bubble).
- [ ] Long-press **selection mode** (delete/duplicate several); Reconcile from Account info.
- [ ] Accounts list preview line = last transaction; sorted by recent activity.

**Done when:** income, expense and transfer can be logged, edited and deleted on all platforms, and `balances:check` reports no drift.

### Phase 4 — Budgets
- [ ] **API:** `BudgetService` create/update with `categoryIds[]` → sets `categories.budget_id`; **409** naming the conflicting budget if a category is taken; archive unlinks the categories.
- [ ] Budget status query (schema doc §6) + rollover-free math; unbudgeted total; `PUT/DELETE /budgets/:id/overrides/:month`.
- [ ] `GET /budgets/:id?month=`: contributing transactions + 6-month history.
- [ ] Tests: multi-category sum, sub-category inheritance, period edges (23:30 IST on the last day), override.
- [ ] **Flutter:** `/budgets` (summary card, tiles with **`RingAvatar`** progress rings + % pill, "Not in any budget" tile).
- [ ] Create/Edit budget form: name, amount, kind, alert %, multi-select categories (taken ones disabled with "in Food & Groceries").
- [ ] `/budgets/:id` **Budget info** (contact-info style): big ring, stat tiles (left, per day, days left), categories, 6-month chart (fl_chart), transactions, "Change this month only", red Archive.
- [ ] After saving an expense, invalidate the budget providers; show `budgetAlerts` as a small chip under the bubble (thread) or a SnackBar (form).

**Done when:** a "Bike EMI + Petrol" budget sums both categories and updates right after a petrol expense is logged.

### Phase 5 — Dashboard, Onboarding & Reports → **MVP**
- [ ] **API:** `GET /dashboard?month=`, `GET /reports/by-category`, `POST /me/onboarding/complete`.
- [ ] **Flutter Home:** balance card (In/Out), **budget rings row** (status-row style), Upcoming with count badge, Recent tiles. Skeleton tiles while loading.
- [ ] **Onboarding wizard** (3 steps: preferences → accounts → budget templates); the router redirects until `onboardedAt` is set.
- [ ] `/reports`: spending donut + ranked list; tap → filtered transactions.
- [ ] Empty and error states everywhere; offline banner.
- [ ] `integration_test`: register → onboarding → add expense → budget and dashboard update (run on Android emulator, Windows, Chrome).
- [ ] Deploy to a staging VPS (see Phase 8 steps) and **use it daily for a week** on phone + laptop.

**🚀 Milestone: MVP v0.1 — all P0 requirements on Android, Windows and Web.**

### Phase 6 — Recurring, Rollover, Alerts, Trends
- [ ] **API:** recurring rules CRUD, upcoming, occurrences confirm/skip.
- [ ] Ace command `recurring:run` (idempotent; day-of-month clamping; advance `next_run_at`) + tests.
- [ ] Budget rollover (≤ 12-month look-back) + tests.
- [ ] `GET /reports/trend`.
- [ ] **Flutter:** "Repeat" field in the transaction form; Settings → Recurring; Dashboard "Upcoming" and "Pending" cards (Confirm opens a prefilled form; Skip); trend chart; rollover shown on budget cards.
- [ ] **Lend & borrow (People):** migration (`people`, `transactions.person_id`/`due_date`, new types + CHECK), balance effects for LEND/BORROW/COLLECT/REPAY + tests, `/people` API (list with balances, settle up, write-off), People list + **person thread** with Lent/Borrowed composer toggle, Home "You'll get / You owe" card, due dates in Upcoming.

### Phase 7 — Platform Polish & Packaging
- [ ] **Dark mode** check of every screen (WhatsApp dark palette: bubbles, wallpaper, chips); golden tests at 3 sizes × 2 themes.
- [ ] **Motion polish pass** against the brief's §2.5 table (tab fill animation, Hero avatars, FAB container transform, bubble send/tick/shake, ring sweep + alert pulse, count-ups, search morph, selection mode). Verify Reduce motion turns them off.
- [ ] **Jank check:** profile mode on a mid-range Android phone + Windows + Chrome; ≥ 99% of frames < 16 ms; fix with `RepaintBoundary`, shader warm-up, fewer stagger items.
- [ ] **Icon audit:** no `Icons.*` or emoji left in the UI; every icon button has a tooltip and semantics label.
- [ ] Our own **doodle wallpaper** SVG (light/dark tints) + Appearance setting (Doodle / Plain / None).
- [ ] **Keyboard & mouse** (Windows/Web): `Shortcuts`/`Actions` (Ctrl+N, Ctrl+F, Esc, Enter), focus order, hover states, context menus, visible scrollbars.
- [ ] **Exports:** CSV and JSON. Web → browser download; Windows → Save dialog; Android → share sheet.
- [ ] Delete account flow; forgot/reset password if deferred.
- [ ] **App identity:** `flutter_launcher_icons` (Android adaptive, Windows .ico, web favicons/manifest) and `flutter_native_splash`.
- [ ] **Android:** release signing config, `flutter build apk --split-per-abi` / `appbundle`, minSdk 24, edge-to-edge, predictive back.
- [ ] **Windows:** `msix` config (name, publisher, logo, self-signed cert) → `dart run msix:create`.
- [ ] **Web:** `flutter build web --release` (try `--wasm`), loading splash in `index.html`, correct base href.
- [ ] Accessibility pass: `Semantics` labels, text scale 200%, contrast, TalkBack/Narrator spot checks.
- [ ] Performance: seed 10k transactions; verify API p95 and smooth list scrolling.

### Phase 8 — Production Deploy & Hardening → **v1.0**
- [ ] VPS setup: Docker + Compose, firewall (22/80/443), non-root user, automatic security updates.
- [ ] `deploy/docker-compose.prod.yml`: `mariadb:11.4` (volume, strong passwords, not publicly exposed), `api` (built image), `caddy` (TLS for `api.<domain>` and `app.<domain>`, serves the Flutter web build, HSTS + CSP headers).
- [ ] Deploy script: build image → `node ace migration:run --force` → restart.
- [ ] Cron: `recurring:run` hourly, `balances:check` nightly, `mariadb-dump` backup nightly → object storage; **test a restore**.
- [ ] Security review: every service filters by `user_id`; rate limits; CORS limited to the web origin; token expiry; no secrets in the Flutter build.
- [ ] Production builds of the APK (pointing to the prod API) and MSIX; install on your phone and PC.
- [ ] Tag `v1.0.0`; GitHub Release with the APK and MSIX attached.

**🚀 Milestone: v1.0 — all P1 requirements.**

## 4. Backlog (v1.x / P2)
- Offline mode (drift/SQLite queue; client UUIDs already support sync)
- Google Sign-In (OAuth browser flow on Windows)
- Local notifications for budget alerts and due bills (Android, Windows)
- Tags, receipt photos, CSV import
- Savings goals, weekly/yearly budgets
- iOS / macOS / Linux builds (same Flutter codebase)
- Play Store / Microsoft Store publishing

## 5. Definition of Done (every task)
- Backend: lint + typecheck pass; Japa tests for business logic; queries scoped by user.
- Flutter: `flutter analyze` clean; unit/widget tests for logic and key widgets.
- Verified on **Android emulator, Windows and Chrome**, at compact and expanded widths, in light and dark themes.
- Loading, empty, error and offline states handled.

## 6. Risks & Dependencies
| Risk | Impact | Mitigation |
|---|---|---|
| Balance bugs in edit flows | High | Test-first in Phase 3; nightly `balances:check` |
| Three platforms triple the QA work | Medium | Adaptive layout by width (not platform); golden tests; one integration test run per platform in CI |
| MariaDB vs MySQL drift | Medium | Compatibility rules in the TRD; CI matrix on both |
| Flutter Web load time | Low–Med | Splash, caching, wasm; web is the secondary platform |
| Scope creep | Medium | P0 only until MVP; backlog the rest |

## 7. Suggested First Commands
```bash
# repo
mkdir backend app deploy && git init

# database: start XAMPP MySQL (MariaDB), or `docker compose up -d` (mariadb:11.4 + adminer)

# backend
nvm install 24 && nvm use 24
npx create-adonisjs@latest backend --kit=api
cd backend
npm uninstall better-sqlite3 && npm i mysql2 uuid
node ace migration:run          # also regenerates database/schema.ts
npm run dev
cd ..

# flutter
flutter create app --org com.hisaabchat --project-name hisaabchat --platforms=android,windows,web
cd app
flutter pub add flutter_riverpod go_router dio freezed_annotation json_annotation \
  flutter_secure_storage shared_preferences intl fl_chart window_manager uuid flutter_timezone
flutter pub add -d build_runner freezed json_serializable very_good_analysis mocktail
flutter run -d chrome  --dart-define=API_BASE_URL=http://localhost:3333/api/v1
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3333/api/v1
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3333/api/v1
```
