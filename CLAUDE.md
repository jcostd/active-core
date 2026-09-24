# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ActiveCore is a Rails 8 ERP for Italian Sports Associations (ASD — Associazioni Sportive Dilettantistiche). It manages members, memberships (*Quota Associativa*), course subscriptions, access control/check-in (including an iPad kiosk mode), point-of-sale, and fiscal receipt generation, per Italian sports-reform rules. Domain terms and validation messages throughout the codebase are in Italian — keep new user-facing strings in Italian to match.

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
- **Membership Guard**: `Sale#require_active_membership_for_courses` blocks selling an institutional (course) product/subscription unless the member has (or will have, on the subscription start date) a valid associative membership. `Member#membership_valid?` is the check, used both here and in `AccessPolicy`.
- **`AccessPolicy`** (`ActiveModel::Model`, not persisted) evaluates a member+discipline pair at check-in time: hard errors (no membership when required, no active subscription for the discipline) vs. soft warnings (expiring medical certificate, subscription expiring soon, low entries remaining). `AccessLog#evaluate_access_policy` runs this on create and stores the resulting `status` enum (`ok`/`warning`/`error`) — kiosk check-in is **non-blocking**: even `error` status logs the entry, staff resolve it manually. `AccessLog` also enforces a double-tap cooldown (`DOUBLE_TAP_TIMEOUT`, 10 min) and a separate kiosk re-suggestion cooldown (`KIOSK_COOLDOWN`, 60 min, see `Member::Filterable.without_recent_checkin_for`).
- **Entry-limited subscriptions** (carnet/PT packages): `entry_limit`/`entries_used` on `Subscription`, incremented/decremented via `AccessLog#after_create_commit`/`after_destroy_commit`. `Subscription.truly_active_at(date)` factors entry exhaustion into "active" (distinct from the plain date-range `active` scope).
- **`PosDraftBuilder`** assembles an unsaved `Sale`+`Subscription` from POS form params, handling three flows distinguished by context params: fresh sale, `renew_subscription_id` (renewal template, continues from old end date), `installment_for_subscription_id` (partial payment toward an existing subscription's `agreed_price`, no new subscription). It resets prices/dates when the product or member selection changes mid-form (`reset_prices_if_identity_changed`).
- **Fiscal receipts**: `Sale` gets a sequential `receipt_number` per `(receipt_year, receipt_sequence)` via `ReceiptCounter.next_number` (only for `cash` payments) — `FiscalLockable` then makes `receipt_number`/`receipt_year`/`receipt_sequence` immutable once set, on any model that includes it. PDFs are generated with Prawn under `app/pdfs/` (`ApplicationPdf` base class).

### Shared model concerns (`app/models/concerns/`)

- `SoftDeletable` — `discard!`/`undiscard!` + `kept`/`discarded` scopes (not a gem; hand-rolled, uses `discarded_at`). Almost all domain models use this instead of hard deletes.
- `Trackable` — auto-writes `ActivityLog` rows (polymorphic `subject`) on create/update/destroy/discard/undiscard, scoped to `Current.user`; sensitive/noisy fields excluded via `IGNORED_FIELDS`.
- `Monetizable` — declarative `monetize :attr` generates float accessors over an `attr_cents` integer column, with locale-aware string parsing (handles both `1.200,50` and `1,200.50` styles). Money is always stored in cents.
- `FtsSearchable` — `search_text(query)` joins against a SQLite FTS5 shadow table (`#{table}_fts`) for full-text search (used by `Member`).
- `Refreshable` — Turbo Stream broadcasting (`broadcasts_refreshes` + broadcast to the plural collection channel) for live UI updates.
- `Personable`, `HasAddress`, `Avatarable` — shared field normalization/validation for person-like and addressable records.
- Per-model `Filterable` concerns (e.g. `Member::Filterable`, `Subscription::Filterable`) hold query scopes and an `apply_filters(params)` class method; controllers delegate filtering/sorting to these rather than building scopes inline.

### Controllers

- `Authentication` concern (cookie/session-based, signed `session_id` cookie, `Current.session`/`Current.user`) is required by default; `allow_unauthenticated_access` opts out per-action. `require_admin` is an explicit opt-in check, not global.
- `Kiosk::*` controllers (under `Kiosk::BaseController`, layout `kiosk`) serve the iPad check-in flow at `/kiosk`, separate from the staff-facing admin UI — treat them as a distinct, touch-first surface (member search, discipline selection, check-in) even though they share models with the main app.
- `Localizable`/`Themable` concerns apply per-user locale (`I18n.available_locales = [:en, :it]`, default `:it`) and daisyUI theme around every request based on `current_user` preferences (stored via `UserPreferences` concern on `User`).

### Frontend

Hotwire (Turbo + Stimulus) with importmaps (no Node/bundler build step), Tailwind CSS 4 + daisyUI 5, Propshaft asset pipeline. Live updates flow through `Refreshable`'s Turbo Stream broadcasts rather than polling.

## Testing conventions

Minitest with fixtures (`test/fixtures/`), parallelized outside CI. `test_helper.rb` defines shared helpers like `grant_membership_to(member)` for seeding a multi-year membership history. Prefer extending existing model/controller test files and fixtures over introducing new test infrastructure.
