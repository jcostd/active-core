# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ActiveCore is a Rails 8 ERP for Italian Sports Associations (ASD — Associazioni Sportive Dilettantistiche). It manages members, memberships (*Quota Associativa*), course subscriptions, a monthly attendance register (iPad kiosk mode), point-of-sale, and fiscal receipt generation, per Italian sports-reform rules. The app is **Italian-only** (ASD is an Italian legal form): UI strings, validation messages, code comments and README are all Italian; there is no locale switching and no `t()` indirection. Attribute names for error messages live in `config/locales/it.yml` (a test fails if a validated attribute lacks one). Keep comments minimal.

Single-tenant: there is one `GymProfile` per deployment (`GymProfile.current`, first-or-create).

## Commands

```bash
bin/setup              # install gems, prepare db, clear logs, then starts server (--skip-server to skip)
bin/dev                # start Rails + Tailwind watcher (Procfile.dev)
bin/ci                 # full CI suite: setup, rubocop, bundler-audit, importmap audit, brakeman, tests, seed replant
bin/rails test                                  # run all Minitest tests
bin/rails test test/models/subscription_test.rb                 # run one file
bin/rails test test/models/subscription_test.rb:20              # run one test at that line
bin/rails test:system  # Capybara/Selenium system tests (SYSTEM_BROWSER=headless_firefox where Chrome is missing)
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

`Member` → `Subscription` (belongs to a `Product`) → `Sale` (payment for a subscription); `Attendance` is the monthly register the instructor fills at the kiosk. Products are either `associative` (membership / Quota Associativa) or `institutional` (courses); this distinction drives most business rules.

- **`Subscription`** dates are auto-calculated by `Duration.for(product, date)` unless explicitly set: associative products run to the end of the `SportYear` (Sept 1–Aug 31; one sold in August covers the next sport year too); institutional products align to calendar months/quarters/rolling year depending on `duration_days`, generally clamped to the current sport year. `Member#next_period_for(product, from:)` is the single answer to "when does the next subscription start": the day after the latest kept subscription of `product.same_line` (same product, a shared discipline, or membership after membership — the same notion as `renewed?`) if that ended within `Member::RENEWAL_GRACE_PERIOD` (30 days), else `from`; then `Duration` aligns it. Renewing is just a POS sale of the same product (`renew_sale_path`).
- **Membership Guard**: `Sale#require_active_membership_for_courses` blocks selling a course unless the member has a valid associative membership on `max(subscription start, sold_on)` (courses aligned to a past month start are checked on the sale day; next-sport-year courses need next year's membership). Courses may run past membership coverage (quarterly, rolling 1-year annual): `Sale#membership_warning` (via `Member#membership_covered_until`) warns in the POS without blocking. Installments skip the guard.
- **Attendance register** (replaces the old per-lesson check-in): one `Attendance` per member, discipline and month (`month` = first day, unique index). The instructor marks whoever they see, once a month, **whatever the subscription** (non-blocking). The current month is editable by whoever calls the roll (kiosk, staff); closed months by admin only; future months by nobody (`Attendance.editable_by?`, enforced on create and in the destroy actions). A discipline is the group the roll is called for (Capoeira Bambini/Ragazzi/Adulti are three disciplines). `Standing` (PORO, never stored) is the member's position for a discipline+month: `not_enrolled` > `no_membership` > `due` > `paid`, plus `certificate_missing?`; computed in memory from `Standing::PRELOAD`. `Attendance.unenrolled` (SQL) = in the register without a subscription of the discipline touching the month: the desk's "to regularize" list (Iscritti page section + dashboard); a test checks it agrees with `Standing`. The old `access_logs` were converted into attendances (month in Rome time) by `CreateAttendances`, then dropped.
- **Private lessons**: `PrivateLesson` is an operational note written at the kiosk (`Kiosk::PrivateLessonsController`) by the teacher, read by the desk (`PrivateLessonsController`, month by month with a per-teacher summary). Teacher and athletes are free-text names (a JSON array, at least one), not `Member`/`User` records — teachers may be external and athletes non-members; names are tidied with `ProperCase.person` and suggested back through native `<datalist>`s (`teacher_names`, `athlete_names`). Traceability only: no prices, no POS. Same month rule as the register (`MonthlyRegister#editable_by?`, checked on the old and new `held_at`); `recorded_by` is whoever saved last.
- **Enrolled members**: `Member.enrolled_in(discipline, during:)` (a kept subscription of the discipline touching the period) is the one definition of "iscritto", shared by the discipline "Iscritti" page (one row per member for a chosen month, with that month's subscriptions and whether the instructor saw them; the desk can mark/unmark there) and the kiosk (proposes this month's enrolled plus last month's register). `kiosk_mirror_test.rb` pins the mirror: enrolled ⊆ proposed ∪ register, register − enrolled = to regularize.
- **No carnets**: entry-limited subscriptions were removed (personal training will be a separate future feature). `Subscription.active_at(date)` = kept and within dates.
- **POS dates**: staff `sold_on` is always today (not permitted in params, enforced by `Sale#staff_dates`); staff can only move the start forward from `member.next_period_for(product)` (the same proposal the POS shows). Admin is free.
- **Fiscal code**: checksum-validated via `FiscalCode` only when new or changed (legacy invalid codes stay editable; `bin/rails members:invalid_fiscal_codes` lists them). `nil` = "CF da completare" (form checkbox `fiscal_code_pending`). Changing `members` columns on SQLite rebuilds the table and drops the FTS triggers: recreate them in the migration (see `AllowPendingFiscalCode`); a test asserts they exist.
- **`Sale::Draft`** completes an unsaved `Sale` (built only from permitted params) with the POS proposals. The controller passes explicit context (`member_id`, `installment_for_subscription_id`, `previous_member_id`/`previous_product_id`, admin-only `override_end_date`) — never raw params. Changing member or product in the form resets prices and dates.
- **`Sale` rules live in concerns under `app/models/sale/`**: `Receiptable`, `Installments`, `MembershipGuard`, `StaffLimits`, `Reversible`. Include order matters (callbacks/validations run in inclusion order; `Installments` must precede the checks that read subscription dates), so each is on its own line.
- **Fiscal receipts**: `Sale` gets a sequential `receipt_number` per `(receipt_year, receipt_sequence)` via `ReceiptCounter.next_number` (only for `cash` payments) — `FiscalLockable` then makes `receipt_number`/`receipt_year`/`receipt_sequence` immutable once set, on any model that includes it. PDFs are generated with Prawn under `app/pdfs/` (`ApplicationPdf` base class).

### Shared model concerns (`app/models/concerns/`)

- `SoftDeletable` — `discard!`/`undiscard!` + `kept`/`discarded` scopes (not a gem; hand-rolled, uses `discarded_at`), wrapped in a transaction so callback cascades are atomic. Almost all domain models use this instead of hard deletes.
- `Monetizable` — `monetize :attr` over an `attr_cents` column; `Monetizable.cents(value)` parses `1.200,50`, `1,200.50`, `12,5`, `€ 45` (thousands only in groups of three, BigDecimal math) and returns nil for non-amounts, which become a validation error. Money is always stored in cents.
- `FtsSearchable` — `search_text(query)` joins against a SQLite FTS5 shadow table (`#{table}_fts`) for full-text search (used by `Member`).
- `Refreshable` — Turbo Stream broadcasting (`broadcasts_refreshes` + broadcast to the plural collection channel) for live UI updates.
- `Personable`, `HasAddress`, `Avatarable` — shared field normalization/validation for person-like and addressable records.
- Per-model `Filterable` concerns (e.g. `Member::Filterable`, `Sale::Filterable`) hold query scopes and an `apply_filters(params)` class method; controllers delegate filtering/sorting to these rather than building scopes inline. Filter scopes return nil (= `all`) when their param is blank or unknown, so `apply_filters` is a plain chain; ordering goes through `Sortable` + a `SORTS` hash per model (first entry = default).

### Controllers

- `Authentication` concern (cookie/session-based, signed `session_id` cookie, `Current.session`/`Current.user`) is required by default; `allow_unauthenticated_access` opts out per-action. `require_admin` is an explicit opt-in check, not global.
- `Kiosk::*` controllers (under `Kiosk::BaseController`, layout `kiosk`) serve the iPad attendance register at `/kiosk`, separate from the staff-facing admin UI — treat them as a distinct, touch-first surface (discipline selection, the month's register, name-only search for walk-ins) even though they share models with the main app.
- `Themable` applies the per-user daisyUI theme (`UserPreferences` concern on `User`). Locale is fixed to `:it` in `config/application.rb`.
- Sessions expire after `Session::IDLE_TIMEOUT` (1h) of inactivity: server side in `Authentication#find_session_by_cookie` (activity write throttled to `ACTIVITY_INTERVAL`) plus the `idle` Stimulus controller on the app layout, because Turbo broadcast refreshes keep sessions alive. The iPad logs in as the fixed `kiosk` user (role `kiosk`, created by migration/seeds, not archivable, role immutable): its sessions live up to `KIOSK_TIMEOUT`, and `Authentication#confine_kiosk_user` redirects it to `/kiosk` from any controller that doesn't override `kiosk_request?` (only `Kiosk::*`, plus logout). Staff/admin can open the kiosk too, with the normal idle timeout. The kiosk never shows fiscal codes or full birth dates. `SessionSweepJob` runs every 15 min via `config/recurring.yml`. ActionCable's connection applies the same rules.
- Permissions: `require_admin` guards admin-only actions server side; views must mirror them. Undo windows live on the models: `Sale#reversible_by?` (staff: own sales within `STAFF_REVERSAL_WINDOW` 15 min; admin: any within `ADMIN_REVERSAL_WINDOW` 24h) and `Subscription#discardable_by?` (all kept payments reversible by that user). Discarding a subscription discards its payments; `SoftDeletable#discard!` is transactional and raises if a callback aborts. The matrix is covered by `test/controllers/authorization_test.rb`.

### Frontend

Hotwire (Turbo + Stimulus) with importmaps (no Node/bundler build step), Tailwind CSS 4 + daisyUI 5, Propshaft asset pipeline. Live updates flow through `Refreshable`'s Turbo Stream broadcasts rather than polling.

- **Live updates (Turbo 8 + Solid Cable)**: models broadcast *refreshes* (`broadcasts_refreshes`); the browser re-fetches the page and morphs it. Layouts emit `turbo_refresh_method_tag :morph` + `turbo_refresh_scroll_tag :preserve` directly (`turbo_refreshes_with` is a `content_for :head` and was silently lost after `yield :head`; `live_updates_test.rb` pins the tags). What must survive a morph is marked with the official `data-turbo-permanent`, no JS patches: the single `turbo-frame#modal` in the app layout (always), the filter drawer (while open, set by `drawer_controller`), the kiosk search. Streams are scoped: `Attendance` → `[discipline, :attendances]` + `"attendances"`; sales/subscriptions reach pages via the member touch (`"members"`). System tests fake a broadcast with `Turbo.renderStreamMessage('<turbo-stream action="refresh">')`.
- **Modals**: links target `data-turbo-frame="modal"`; `layouts/modal` renders the daisyUI `<dialog class="modal">` (✕ and backdrop are native `form method="dialog"`) for frame requests and a normal page (via `content_for :page` + the app layout) when the URL is opened directly. Forms stay inside the frame: errors re-render there (422); success answers `turbo_refresh_or_redirect_to` (a refresh stream, or a redirect for full-page requests) and `dialog#closeAfterSave` closes the dialog on a successful non-GET `turbo:submit-end` (the frame is permanent, so the refresh alone would not). Closing empties the frame. `modal_pages_test.rb` + `test/system/javascript_test.rb` cover it.

- **Presentation maps**: status icons/colors live in one place each (`SubscriptionsHelper::SUBSCRIPTION_STATUS_STYLES`, `StandingsHelper` for the register, `UiHelper::BADGE_TONES`) with literal class names — Tailwind only generates classes written out in full; `view_conventions_test.rb` fails on `bg-<%= … %>` in views or `-#{…}` in helpers. Index pages use `render layout: "shared/filter/form"` + `filter_select`.
- **daisyUI 5 idioms**: prefer components over utility soup (`fieldset`/`fieldset-legend`, `modal modal-end` for side panels, `menu` with `<button>` items, `btn` on `input[type=checkbox]` with `aria-label` for pill toggles). No daisyUI 4 classes (`*-bordered`, `form-control`, `label-text`). Clickable things are `<button>`/`<a>`, never `div`/`li`. `test/integration/html_validity_test.rb` parses the main pages as HTML5.
- **Caching**: production cache is Solid Cache (SQLite), so every read is a query. Use collection caching (`render collection:, cached: ->(x) { key }`, one `read_multi`) instead of `cache` blocks per item; keys must include everything the fragment depends on (role, `Date.current`, associated records such as `member.subscriptions.map(&:product)`). Tiny hot data (SVG icons) is cached in-process (`IconsHelper::SVG_CACHE`), not in `Rails.cache`.
- **Queries**: `Subscription.preload_renewed(list)` batches `renewed?` for list pages; the kiosk uses `preload` (not `includes`) so memberships aren't filtered out. Kiosk cards are collection-cached with the standing (`key`, `certificate_missing?`) in the key, since it depends on data that doesn't touch the member. `test/integration/query_budget_test.rb` asserts list pages don't grow queries with rows.

## Testing conventions

Minitest with fixtures (`test/fixtures/`, users `staff`, `staff_two`, `admin`), parallelized outside CI. `test_helper.rb` defines shared helpers like `grant_membership_to(member)` for seeding a multi-year membership history; `with_fragment_caching` (in `test/test_helpers/`) enables real fragment/collection caching for a block, since the test env uses `:null_store`; `sell!`/`link!` create a sale+subscription or product↔discipline links in one line. `TEST_NOW="2027-01-01 10:00" bin/rails test` runs the whole suite (fixture ERB included, since the travel happens before fixtures load) at that moment — use it to check calendar edges (Jan 1 membership receipts, Aug 31/Sep 1 sport year, DST). Tests must not assume today's date. Prefer extending existing model/controller test files and fixtures over introducing new test infrastructure.
