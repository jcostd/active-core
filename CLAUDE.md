# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ActiveCore is a Rails 8 ERP for Italian Sports Associations (ASD — Associazioni Sportive Dilettantistiche). It manages members, memberships (*Quota Associativa*), course subscriptions, access control/check-in (including an iPad kiosk mode), point-of-sale, and fiscal receipt generation, per Italian sports-reform rules. The app is **Italian-only** (ASD is an Italian legal form): UI strings, validation messages, code comments and README are all Italian; there is no locale switching and no `t()` indirection. Attribute names for error messages live in `config/locales/it.yml` (a test fails if a validated attribute lacks one). Keep comments minimal.

Single-tenant: there is one `GymProfile` per deployment (`GymProfile.current`, first-or-create).

## Commands

```bash
bin/setup              # install gems, prepare db, clear logs, then starts server (--skip-server to skip)
bin/dev                # start Rails + Tailwind watcher (Procfile.dev)
bin/ci                 # full CI suite: setup, rubocop, bundler-audit, importmap audit, brakeman, tests, seed replant
bin/rails test                                  # run all Minitest tests
bin/rails test test/models/subscription_test.rb                 # run one file
bin/rails test test/models/subscription_test.rb:20              # run one test at that line
bin/rails test:system  # Capybara/Selenium system tests
bin/rubocop             # lint (Omakase style, rubocop-rails-omakase)
bin/rubocop -A          # autocorrect
bin/brakeman --no-pager # static security analysis
bin/bundler-audit        # gem CVE audit
bin/importmap audit      # JS dependency audit
```

`bin/ci` (invoked via `config/ci.rb`, using `ActiveSupport::ContinuousIntegration`) is the authoritative pre-merge gate and mirrors `.github/workflows/ci.yml` — run it (or the individual steps) before considering work done.

Database is SQLite with `schema_format: :sql` for the primary db (`db/structure.sql`, not `schema.rb`); Solid Cache/Queue/Cable use separate SQLite databases with their own `:ruby`-format schemas under `db/*_schema.rb`.

## Architecture

### Core domain flow

`Member` → `Subscription` (belongs to a `Product`) → `Sale` (payment for a subscription) → `AccessLog` (check-in, evaluated against `AccessPolicy`). Products are either `associative` (membership / Quota Associativa) or `institutional` (courses); this distinction drives most business rules.

- **`Subscription`** dates are auto-calculated by `Duration.for(product, date)` unless explicitly set: associative products align to the `SportYear` (Sept 1–Aug 31); institutional products align to calendar months/quarters/rolling year depending on `duration_days`, generally clamped to the current sport year. `Member#suggested_start_date_for` implements renewal continuity: if a new subscription starts within `Member::RENEWAL_GRACE_PERIOD` (30 days) of the previous one ending, it starts the day after the old one ends instead of on the reference date.
- **Membership Guard**: `Sale#require_active_membership_for_courses` blocks selling a course unless the member has a valid associative membership on `max(subscription start, sold_on)` (courses aligned to a past month start are checked on the sale day; next-sport-year courses need next year's membership). Courses may run past membership coverage (quarterly, rolling 1-year annual): `Sale#membership_warning` (via `Member#membership_covered_until`) warns in the POS without blocking. Installments skip the guard.
- **`AccessPolicy`** (`ActiveModel::Model`, not persisted) evaluates a member+discipline pair at check-in time: hard errors (no membership when required, no active subscription for the discipline) vs. soft warnings (expiring medical certificate, subscription expiring soon, low entries remaining). `AccessLog#evaluate_access_policy` runs this on create and stores the resulting `status` enum (`ok`/`warning`/`error`) — kiosk check-in is **non-blocking**: even `error` status logs the entry, staff resolve it manually. `AccessLog` also enforces a double-tap cooldown (`DOUBLE_TAP_TIMEOUT`, 10 min) and a separate kiosk re-suggestion cooldown (`KIOSK_COOLDOWN`, 60 min, see `Member::Filterable.without_recent_checkin_for`).
- **No carnets**: entry-limited subscriptions were removed (personal training will be a separate future feature). `Subscription.active_at(date)` = kept and within dates. Kiosk check-ins cannot be cancelled from the kiosk.
- **POS dates**: staff `sold_on` is always today (not permitted in params, enforced by `Sale#staff_dates`); staff can only move the start forward from `Subscription.proposed_start_date` (same helper the builder uses). Admin is free.
- **Fiscal code**: checksum-validated via `FiscalCode` only when new or changed (legacy invalid codes stay editable; `bin/rails members:invalid_fiscal_codes` lists them). `nil` = "CF da completare" (form checkbox `fiscal_code_pending`). Changing `members` columns on SQLite rebuilds the table and drops the FTS triggers: recreate them in the migration (see `AllowPendingFiscalCode`); a test asserts they exist.
- **`Sale::Draft`** completes an unsaved `Sale` (built only from permitted params) with the POS proposals. The controller passes explicit context (`member_id`, `renew_subscription_id`, `installment_for_subscription_id`, `previous_member_id`/`previous_product_id`, admin-only `override_end_date`) — never raw params. Changing member or product in the form resets prices and dates.
- **`Sale` rules live in concerns under `app/models/sale/`**: `Receiptable`, `Installments`, `MembershipGuard`, `StaffLimits`, `Reversible`. Include order matters (callbacks/validations run in inclusion order; `Installments` must precede the checks that read subscription dates), so each is on its own line.
- **Fiscal receipts**: `Sale` gets a sequential `receipt_number` per `(receipt_year, receipt_sequence)` via `ReceiptCounter.next_number` (only for `cash` payments) — `FiscalLockable` then makes `receipt_number`/`receipt_year`/`receipt_sequence` immutable once set, on any model that includes it. PDFs are generated with Prawn under `app/pdfs/` (`ApplicationPdf` base class).

### Shared model concerns (`app/models/concerns/`)

- `SoftDeletable` — `discard!`/`undiscard!` + `kept`/`discarded` scopes (not a gem; hand-rolled, uses `discarded_at`), wrapped in a transaction so callback cascades are atomic. Almost all domain models use this instead of hard deletes.
- `Trackable` — auto-writes `ActivityLog` rows (polymorphic `subject`) on create/update/destroy/discard/undiscard, scoped to `Current.user`; sensitive/noisy fields excluded via `IGNORED_FIELDS`.
- `Monetizable` — `monetize :attr` over an `attr_cents` column; `Monetizable.cents(value)` parses `1.200,50`, `1,200.50`, `12,5`, `€ 45` (thousands only in groups of three, BigDecimal math) and returns nil for non-amounts, which become a validation error. Money is always stored in cents.
- `FtsSearchable` — `search_text(query)` joins against a SQLite FTS5 shadow table (`#{table}_fts`) for full-text search (used by `Member`).
- `Refreshable` — Turbo Stream broadcasting (`broadcasts_refreshes` + broadcast to the plural collection channel) for live UI updates.
- `Personable`, `HasAddress`, `Avatarable` — shared field normalization/validation for person-like and addressable records.
- Per-model `Filterable` concerns (e.g. `Member::Filterable`, `Subscription::Filterable`) hold query scopes and an `apply_filters(params)` class method; controllers delegate filtering/sorting to these rather than building scopes inline.

### Controllers

- `Authentication` concern (cookie/session-based, signed `session_id` cookie, `Current.session`/`Current.user`) is required by default; `allow_unauthenticated_access` opts out per-action. `require_admin` is an explicit opt-in check, not global.
- `Kiosk::*` controllers (under `Kiosk::BaseController`, layout `kiosk`) serve the iPad check-in flow at `/kiosk`, separate from the staff-facing admin UI — treat them as a distinct, touch-first surface (member search, discipline selection, check-in) even though they share models with the main app.
- `Themable` applies the per-user daisyUI theme (`UserPreferences` concern on `User`). Locale is fixed to `:it` in `config/application.rb`.
- Sessions expire after `Session::IDLE_TIMEOUT` (1h) of inactivity: server side in `Authentication#find_session_by_cookie` (activity write throttled to `ACTIVITY_INTERVAL`) plus the `idle` Stimulus controller on the app layout, because Turbo broadcast refreshes keep sessions alive. The iPad logs in as the fixed `kiosk` user (role `kiosk`, created by migration/seeds, not archivable, role immutable): its sessions live up to `KIOSK_TIMEOUT`, and `Authentication#confine_kiosk_user` redirects it to `/kiosk` from any controller that doesn't override `kiosk_request?` (only `Kiosk::*`, plus logout). Staff/admin can open the kiosk too, with the normal idle timeout. The kiosk never shows fiscal codes or full birth dates. `SessionSweepJob` runs every 15 min via `config/recurring.yml`. ActionCable's connection applies the same rules.
- Permissions: `require_admin` guards admin-only actions server side; views must mirror them. Undo windows live on the models: `Sale#reversible_by?` (staff: own sales within `STAFF_REVERSAL_WINDOW` 15 min; admin: any within `ADMIN_REVERSAL_WINDOW` 24h) and `Subscription#discardable_by?` (all kept payments reversible by that user). Discarding a subscription discards its payments; `SoftDeletable#discard!` is transactional and raises if a callback aborts. The matrix is covered by `test/controllers/authorization_test.rb`.

### Frontend

Hotwire (Turbo + Stimulus) with importmaps (no Node/bundler build step), Tailwind CSS 4 + daisyUI 5, Propshaft asset pipeline. Live updates flow through `Refreshable`'s Turbo Stream broadcasts rather than polling.

- **Presentation maps**: status icons/colors live in one place each (`SubscriptionsHelper::SUBSCRIPTION_STATUS_STYLES`, `AccessLogsHelper::ACCESS_LOG_STATUS_STYLES`, `KioskHelper`, `UiHelper::BADGE_TONES`) with literal class names — Tailwind only generates classes written out in full; `view_conventions_test.rb` fails on `bg-<%= … %>` in views or `-#{…}` in helpers. Index pages use `render layout: "shared/filter/form"` + `filter_select`.
- **daisyUI 5 idioms**: prefer components over utility soup (`fieldset`/`fieldset-legend`, `modal modal-end` for side panels, `menu` with `<button>` items, `btn` on `input[type=checkbox]` with `aria-label` for pill toggles). No daisyUI 4 classes (`*-bordered`, `form-control`, `label-text`). Clickable things are `<button>`/`<a>`, never `div`/`li`. `test/integration/html_validity_test.rb` parses the main pages as HTML5.
- **Caching**: production cache is Solid Cache (SQLite), so every read is a query. Use collection caching (`render collection:, cached: ->(x) { key }`, one `read_multi`) instead of `cache` blocks per item; keys must include everything the fragment depends on (role, `Date.current`, associated records such as `member.subscriptions.map(&:product)`). Tiny hot data (SVG icons) is cached in-process (`IconsHelper::SVG_CACHE`), not in `Rails.cache`.
- **Queries**: `Subscription.preload_renewed(list)` batches `renewed?` for list pages; the kiosk uses `preload` (not `includes`) so memberships aren't filtered out. `test/integration/query_budget_test.rb` asserts list pages don't grow queries with rows.

## Testing conventions

Minitest with fixtures (`test/fixtures/`, users `staff`, `staff_two`, `admin`), parallelized outside CI. `test_helper.rb` defines shared helpers like `grant_membership_to(member)` for seeding a multi-year membership history; `with_fragment_caching` (in `test/test_helpers/`) enables real fragment/collection caching for a block, since the test env uses `:null_store`; `sell!`/`link!` create a sale+subscription or product↔discipline links in one line. `TEST_NOW="2027-01-01 10:00" bin/rails test` runs the whole suite (fixture ERB included, since the travel happens before fixtures load) at that moment — use it to check calendar edges (Jan 1 membership receipts, Aug 31/Sep 1 sport year, DST). Tests must not assume today's date. Prefer extending existing model/controller test files and fixtures over introducing new test infrastructure.
