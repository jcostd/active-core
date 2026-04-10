CREATE TABLE IF NOT EXISTS "disciplines" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "discarded_at" datetime(6), "name" varchar NOT NULL, "requires_medical_certificate" boolean DEFAULT TRUE NOT NULL, "requires_membership" boolean DEFAULT TRUE NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_disciplines_on_discarded_at" ON "disciplines" ("discarded_at");
CREATE UNIQUE INDEX "index_disciplines_on_name" ON "disciplines" ("name") WHERE discarded_at IS NULL;
CREATE TABLE IF NOT EXISTS "gym_profiles" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "address_line_1" varchar, "address_line_2" varchar, "bank_iban" varchar, "city" varchar, "created_at" datetime(6) NOT NULL, "email" varchar, "name" varchar, "phone" varchar, "updated_at" datetime(6) NOT NULL, "vat_number" varchar, "zip_code" varchar);
CREATE TABLE IF NOT EXISTS "products" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "accounting_category" varchar DEFAULT 'institutional' NOT NULL, "created_at" datetime(6) NOT NULL, "discarded_at" datetime(6), "duration_days" integer NOT NULL, "name" varchar NOT NULL, "price_cents" integer DEFAULT 0 NOT NULL, "updated_at" datetime(6) NOT NULL, "entry_limit" integer /*application='ActiveCore'*/);
CREATE INDEX "index_products_on_discarded_at" ON "products" ("discarded_at");
CREATE UNIQUE INDEX "index_products_on_name" ON "products" ("name") WHERE discarded_at IS NULL;
CREATE TABLE IF NOT EXISTS "receipt_counters" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "last_number" integer DEFAULT 0 NOT NULL, "sequence_category" varchar NOT NULL, "updated_at" datetime(6) NOT NULL, "year" integer NOT NULL);
CREATE UNIQUE INDEX "index_receipt_counters_on_year_and_sequence_category" ON "receipt_counters" ("year", "sequence_category");
CREATE TABLE IF NOT EXISTS "activity_logs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "action" varchar NOT NULL, "changes_set" json DEFAULT '{}', "created_at" datetime(6) NOT NULL, "subject_id" integer NOT NULL, "subject_type" varchar NOT NULL, "updated_at" datetime(6) NOT NULL, "user_id" integer NOT NULL, CONSTRAINT "fk_rails_c9badf82db"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_activity_logs_on_subject" ON "activity_logs" ("subject_type", "subject_id");
CREATE INDEX "index_activity_logs_on_user_id_and_created_at" ON "activity_logs" ("user_id", "created_at");
CREATE INDEX "index_activity_logs_on_user_id" ON "activity_logs" ("user_id");
CREATE TABLE IF NOT EXISTS "feedbacks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "admin_notes" text, "browser_info" varchar, "created_at" datetime(6) NOT NULL, "message" text NOT NULL, "page_url" varchar, "status" integer DEFAULT 0 NOT NULL, "updated_at" datetime(6) NOT NULL, "user_id" integer NOT NULL, CONSTRAINT "fk_rails_c57bb6cf28"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_feedbacks_on_status" ON "feedbacks" ("status");
CREATE INDEX "index_feedbacks_on_user_id" ON "feedbacks" ("user_id");
CREATE TABLE IF NOT EXISTS "product_disciplines" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "discipline_id" integer NOT NULL, "product_id" integer NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_78b6087a54"
FOREIGN KEY ("discipline_id")
  REFERENCES "disciplines" ("id")
, CONSTRAINT "fk_rails_3e95f394f9"
FOREIGN KEY ("product_id")
  REFERENCES "products" ("id")
);
CREATE INDEX "index_product_disciplines_on_discipline_id" ON "product_disciplines" ("discipline_id");
CREATE UNIQUE INDEX "index_product_disciplines_on_product_id_and_discipline_id" ON "product_disciplines" ("product_id", "discipline_id");
CREATE INDEX "index_product_disciplines_on_product_id" ON "product_disciplines" ("product_id");
CREATE TABLE IF NOT EXISTS "sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "ip_address" varchar, "updated_at" datetime(6) NOT NULL, "user_agent" varchar, "user_id" integer NOT NULL, CONSTRAINT "fk_rails_758836b4f0"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id");
CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "access_logs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "checkin_by_user_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "entered_at" datetime(6) NOT NULL, "medical_certificate_valid" boolean DEFAULT FALSE NOT NULL, "member_id" integer NOT NULL, "subscription_id" integer, "updated_at" datetime(6) NOT NULL, "discipline_id" integer, "status" integer DEFAULT 0 NOT NULL /*application='ActiveCore'*/, CONSTRAINT "fk_rails_df50081f1b"
FOREIGN KEY ("subscription_id")
  REFERENCES "subscriptions" ("id")
, CONSTRAINT "fk_rails_21592df11b"
FOREIGN KEY ("member_id")
  REFERENCES "members" ("id")
, CONSTRAINT "fk_rails_1f32fe057e"
FOREIGN KEY ("checkin_by_user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_94f46a97ff"
FOREIGN KEY ("discipline_id")
  REFERENCES "disciplines" ("id")
);
CREATE INDEX "index_access_logs_on_checkin_by_user_id" ON "access_logs" ("checkin_by_user_id") /*application='ActiveCore'*/;
CREATE INDEX "index_access_logs_on_entered_at" ON "access_logs" ("entered_at") /*application='ActiveCore'*/;
CREATE INDEX "index_access_logs_on_member_id_and_entered_at" ON "access_logs" ("member_id", "entered_at") /*application='ActiveCore'*/;
CREATE INDEX "index_access_logs_on_member_id" ON "access_logs" ("member_id") /*application='ActiveCore'*/;
CREATE INDEX "index_access_logs_on_subscription_id" ON "access_logs" ("subscription_id") /*application='ActiveCore'*/;
CREATE INDEX "index_access_logs_on_discipline_id" ON "access_logs" ("discipline_id") /*application='ActiveCore'*/;
CREATE INDEX "index_access_logs_on_status" ON "access_logs" ("status") /*application='ActiveCore'*/;
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "discarded_at" datetime(6), "email_address" varchar NOT NULL, "first_name" varchar NOT NULL, "full_name" varchar GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL, "last_name" varchar NOT NULL, "password_digest" varchar NOT NULL, "preferences" json DEFAULT '{}', "role" integer DEFAULT 0 NOT NULL, "updated_at" datetime(6) NOT NULL, "username" varchar NOT NULL);
CREATE INDEX "index_users_on_discarded_at" ON "users" ("discarded_at") /*application='ActiveCore'*/;
CREATE UNIQUE INDEX "index_users_on_email_address" ON "users" ("email_address") WHERE discarded_at IS NULL /*application='ActiveCore'*/;
CREATE INDEX "index_users_on_preferences" ON "users" ("preferences") /*application='ActiveCore'*/;
CREATE INDEX "index_users_on_role" ON "users" ("role") /*application='ActiveCore'*/;
CREATE UNIQUE INDEX "index_users_on_username" ON "users" ("username") WHERE discarded_at IS NULL /*application='ActiveCore'*/;
CREATE TABLE IF NOT EXISTS "members" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "address" varchar, "birth_date" date NOT NULL, "city" varchar, "created_at" datetime(6) NOT NULL, "discarded_at" datetime(6), "email_address" varchar, "first_name" varchar NOT NULL, "fiscal_code" varchar NOT NULL, "full_address" varchar GENERATED ALWAYS AS (address || ', ' || city || ' (' || zip_code || ')') VIRTUAL, "full_name" varchar GENERATED ALWAYS AS (first_name || ' ' || last_name) VIRTUAL, "last_name" varchar NOT NULL, "medical_certificate_expiry" date, "phone" varchar, "updated_at" datetime(6) NOT NULL, "zip_code" varchar);
CREATE INDEX "index_members_on_discarded_at" ON "members" ("discarded_at") /*application='ActiveCore'*/;
CREATE UNIQUE INDEX "index_members_on_fiscal_code" ON "members" ("fiscal_code") WHERE discarded_at IS NULL /*application='ActiveCore'*/;
CREATE INDEX "index_members_on_full_address" ON "members" ("full_address") /*application='ActiveCore'*/;
CREATE INDEX "index_members_on_full_name" ON "members" ("full_name") /*application='ActiveCore'*/;
CREATE INDEX "index_members_on_medical_certificate_expiry" ON "members" ("medical_certificate_expiry") /*application='ActiveCore'*/;
CREATE VIRTUAL TABLE members_fts USING fts5(
        first_name,
        last_name,
        fiscal_code,
        email_address,
        phone,
        birth_date,
        content='members',
        content_rowid='id'
      )
/* members_fts(first_name,last_name,fiscal_code,email_address,phone,birth_date) */;
CREATE TRIGGER members_ai AFTER INSERT ON members BEGIN
        INSERT INTO members_fts(rowid, first_name, last_name, fiscal_code, email_address, phone, birth_date)
        VALUES (new.id, new.first_name, new.last_name, new.fiscal_code, new.email_address, new.phone, new.birth_date);
      END;
CREATE TRIGGER members_ad AFTER DELETE ON members BEGIN
        INSERT INTO members_fts(members_fts, rowid, first_name, last_name, fiscal_code, email_address, phone, birth_date)
        VALUES ('delete', old.id, old.first_name, old.last_name, old.fiscal_code, old.email_address, old.phone, old.birth_date);
      END;
CREATE TRIGGER members_au AFTER UPDATE ON members BEGIN
        INSERT INTO members_fts(members_fts, rowid, first_name, last_name, fiscal_code, email_address, phone, birth_date)
        VALUES ('delete', old.id, old.first_name, old.last_name, old.fiscal_code, old.email_address, old.phone, old.birth_date);

        INSERT INTO members_fts(rowid, first_name, last_name, fiscal_code, email_address, phone, birth_date)
        VALUES (new.id, new.first_name, new.last_name, new.fiscal_code, new.email_address, new.phone, new.birth_date);
      END;
CREATE TABLE IF NOT EXISTS "sales" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "amount_cents" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "discarded_at" datetime(6), "member_id" integer NOT NULL, "notes" text, "payment_method" integer DEFAULT 0 NOT NULL, "product_id" integer NOT NULL, "product_name_snapshot" varchar NOT NULL, "receipt_code" varchar GENERATED ALWAYS AS (receipt_year || '-' || receipt_sequence || '-' || receipt_number) STORED, "receipt_number" integer, "receipt_sequence" varchar, "receipt_year" integer, "sold_on" date NOT NULL, "updated_at" datetime(6) NOT NULL, "user_id" integer NOT NULL, "subscription_id" integer, CONSTRAINT "fk_rails_8e94f16ccc"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
, CONSTRAINT "fk_rails_935e249f94"
FOREIGN KEY ("member_id")
  REFERENCES "members" ("id")
, CONSTRAINT "fk_rails_afd82832c8"
FOREIGN KEY ("product_id")
  REFERENCES "products" ("id")
, CONSTRAINT "fk_rails_26eed2fa3b"
FOREIGN KEY ("subscription_id")
  REFERENCES "subscriptions" ("id")
);
CREATE INDEX "index_sales_on_discarded_at" ON "sales" ("discarded_at") /*application='ActiveCore'*/;
CREATE INDEX "index_sales_on_member_id" ON "sales" ("member_id") /*application='ActiveCore'*/;
CREATE INDEX "index_sales_on_product_id" ON "sales" ("product_id") /*application='ActiveCore'*/;
CREATE INDEX "index_sales_on_receipt_code" ON "sales" ("receipt_code") /*application='ActiveCore'*/;
CREATE UNIQUE INDEX "idx_on_receipt_year_receipt_sequence_receipt_number_3689acdaf9" ON "sales" ("receipt_year", "receipt_sequence", "receipt_number") WHERE receipt_number IS NOT NULL /*application='ActiveCore'*/;
CREATE INDEX "index_sales_on_sold_on" ON "sales" ("sold_on") /*application='ActiveCore'*/;
CREATE INDEX "index_sales_on_user_id" ON "sales" ("user_id") /*application='ActiveCore'*/;
CREATE INDEX "index_sales_on_subscription_id" ON "sales" ("subscription_id") /*application='ActiveCore'*/;
CREATE TABLE IF NOT EXISTS "subscriptions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "discarded_at" datetime(6), "end_date" date NOT NULL, "member_id" integer NOT NULL, "product_id" integer NOT NULL, "start_date" date NOT NULL, "suspension_days_count" integer DEFAULT 0 NOT NULL, "updated_at" datetime(6) NOT NULL, "entry_limit" integer, "agreed_price_cents" integer DEFAULT 0 NOT NULL /*application='ActiveCore'*/, CONSTRAINT "fk_rails_52a3b81fce"
FOREIGN KEY ("product_id")
  REFERENCES "products" ("id")
, CONSTRAINT "fk_rails_bfac3ecd2f"
FOREIGN KEY ("member_id")
  REFERENCES "members" ("id")
);
CREATE INDEX "index_subscriptions_on_discarded_at" ON "subscriptions" ("discarded_at") /*application='ActiveCore'*/;
CREATE INDEX "index_subscriptions_on_member_id_and_end_date" ON "subscriptions" ("member_id", "end_date") /*application='ActiveCore'*/;
CREATE INDEX "index_subscriptions_on_member_id" ON "subscriptions" ("member_id") /*application='ActiveCore'*/;
CREATE INDEX "index_subscriptions_on_product_id" ON "subscriptions" ("product_id") /*application='ActiveCore'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260410181021'),
('20260401155455'),
('20260401155446'),
('20260323183701'),
('20260323182713'),
('20260323182158'),
('20260123203107'),
('20260123203106'),
('20260123203105'),
('20251229165659'),
('20251226140721'),
('20251226095450'),
('20251226095447'),
('20251226095443'),
('20251226095251'),
('20251226094829'),
('20251226094653'),
('20251226093936'),
('20251226093721'),
('20251226092633'),
('20251226082018'),
('20251226082017');

