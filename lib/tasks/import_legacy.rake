module Source
  DB_FILE = "legacy.sqlite3"

  class Base < ActiveRecord::Base
    self.abstract_class = true
    establish_connection(adapter: "sqlite3", database: Rails.root.join("storage", DB_FILE))
  end

  # --- CLASSI CON RELAZIONI CORRETTE ---

  class User < Base
    self.table_name = "users"
  end

  class Activity < Base
    self.table_name = "activities"
    # FIX: Aggiunta la relazione mancante has_many
    has_many :activity_plans, class_name: "Source::ActivityPlan", foreign_key: "activity_id"
  end

  class ActivityPlan < Base
    self.table_name = "activity_plans"
    belongs_to :activity, class_name: "Source::Activity"
  end

  class Membership < Base
    self.table_name = "memberships"
  end

  class Subscription < Base
    self.table_name = "subscriptions"
    belongs_to :activity_plan, class_name: "Source::ActivityPlan"
  end

  class Payment < Base
    self.table_name = "payments"
    has_one :payment_membership, class_name: "Source::PaymentMembership", foreign_key: "payment_id"
    has_one :payment_subscription, class_name: "Source::PaymentSubscription", foreign_key: "payment_id"
    has_one :receipt, class_name: "Source::Receipt", foreign_key: "payment_id"
  end

  class PaymentMembership < Base
    self.table_name = "payment_memberships"
  end

  class PaymentSubscription < Base
    self.table_name = "payment_subscriptions"
    belongs_to :subscription, class_name: "Source::Subscription"
  end

  class Receipt < Base
    self.table_name = "receipts"
    has_one :receipt_membership, class_name: "Source::ReceiptMembership", foreign_key: "receipt_id"
    has_one :receipt_subscription, class_name: "Source::ReceiptSubscription", foreign_key: "receipt_id"
  end

  class ReceiptMembership < Base; self.table_name = "receipt_memberships"; end
  class ReceiptSubscription < Base; self.table_name = "receipt_subscriptions"; end
end

namespace :legacy do
  # Mappe di Conversione
  PLAN_MAP = {
    0 => { days: 1,   suffix: "Ingresso Singolo" },
    1 => { days: 15,  suffix: "Quindicinale" },
    2 => { days: 30,  suffix: "Mensile" },
    3 => { days: 30,  suffix: "Mensile (1 Lez.)" },
    4 => { days: 30,  suffix: "Mensile (2 Lez.)" },
    5 => { days: 90,  suffix: "Trimestrale" },
    6 => { days: 365, suffix: "Annuale" }
  }.freeze

  PAYMENT_METHOD_MAP = { 0 => :cash, 1 => :credit_card, 2 => :bank_transfer, 3 => :other }.freeze

  desc "Esegue l'importazione completa in ordine (Membri -> Prodotti -> Storico)"
  task all: [ :members, :products, :history ]

  # ------------------------------------------------------------------------------
  # TASK MEMBRI
  # ------------------------------------------------------------------------------
  task members: :environment do
    puts "\n👤 [1/3] Importazione Membri..."
    stats = { created: 0, updated: 0, errors: 0 }

    Source::User.find_each do |old|
      next if old.name.blank? && old.surname.blank?

      cf_clean = old.cf.to_s.strip.upcase
      cf_clean = "INVALIDCF#{old.id}".ljust(16, "X") if cf_clean.blank? || cf_clean.length != 16

      phone_clean = old.phone.to_s.gsub(/[^0-9+]/, "")
      phone_clean = nil if phone_clean.length < 6

      birth_date = old.birth_day || Date.new(1900, 1, 1)
      med_cert_expiry = old.med_cert_issue_date ? old.med_cert_issue_date + 1.year : nil

      member = Member.find_or_initialize_by(fiscal_code: cf_clean)
      member = Member.find_or_initialize_by(email_address: old.email) if member.new_record? && old.email.present?

      member.assign_attributes(
        first_name: old.name.strip,
        last_name:  old.surname.strip,
        fiscal_code: cf_clean,
        birth_date: birth_date,
        email_address: old.email.presence,
        phone: phone_clean,
        medical_certificate_expiry: med_cert_expiry
      )

      if member.save
        member.previously_new_record? ? stats[:created] += 1 : stats[:updated] += 1
        print "."
      else
        if member.errors[:phone].any?
          member.phone = nil
          if member.save
            stats[:created] += 1
            print "f"
            next
          end
        end
        stats[:errors] += 1
      end
    end
    puts "\n✅ Membri completati: #{stats}"
  end

  # ------------------------------------------------------------------------------
  # TASK PRODOTTI
  # ------------------------------------------------------------------------------
  task products: :environment do
    puts "\n📦 [2/3] Importazione Prodotti..."

    mem_prod = Product.find_or_initialize_by(name: "Quota Associativa / Tesseramento")
    mem_prod.update!(price_cents: 3500, duration_days: 365, accounting_category: "associative")
    puts "✅ Quota Associativa ok"

    Source::Activity.find_each do |old_act|
      discipline_name = old_act.name.squish.titleize
      discipline = Discipline.find_or_create_by(name: discipline_name)

      # FIX: Ora activity_plans funzionerà perché ho aggiunto has_many su Source::Activity
      old_act.activity_plans.each do |old_plan|
        map = PLAN_MAP[old_plan.plan]
        next unless map

        product_name = "#{discipline.name} - #{map[:suffix]}"
        price = (old_plan.cost.to_f * 100).to_i

        product = Product.find_or_initialize_by(name: product_name)
        product.assign_attributes(
          price_cents: price,
          duration_days: map[:days],
          accounting_category: "institutional"
        )

        if product.save
          ProductDiscipline.find_or_create_by!(product: product, discipline: discipline)
          print "."
        end
      end
    end
    puts "\n✅ Prodotti completati."
  end

  # ------------------------------------------------------------------------------
  # TASK STORICO
  # ------------------------------------------------------------------------------
  task history: :environment do
    puts "\n💰 [3/3] Importazione Storico..."

    admin = User.find_or_create_by!(username: "admin_migrazione") do |u|
      u.email_address = "migration@system.local"
      u.first_name = "Admin"; u.last_name = "Migrazione"
      u.role = :admin; u.password = "Migration2025!"
      u.password_confirmation = "Migration2025!"
    end

    ActiveRecord::Base.transaction do
      Source::Payment.find_each do |old_pay|
        begin
          old_uid = old_pay.payment_membership&.user_id || old_pay.payment_subscription&.user_id
          next unless old_uid

          old_user = Source::User.find_by(id: old_uid)
          next unless old_user

          clean_cf = old_user.cf.to_s.strip.upcase
          clean_cf = "INVALIDCF#{old_user.id}".ljust(16, "X") if clean_cf.length != 16

          member = Member.find_by(fiscal_code: clean_cf)
          member ||= Member.find_by(email_address: old_user.email) if old_user.email.present?
          next unless member

          product = nil
          start_date, end_date = nil, nil

          if old_pay.payment_membership
            product = Product.find_by(name: "Quota Associativa / Tesseramento")
            ref = Source::Membership.find(old_pay.payment_membership.membership_id)
            start_date, end_date = ref.start_date, ref.end_date
          elsif old_pay.payment_subscription
            sub_ref = Source::Subscription.find(old_pay.payment_subscription.subscription_id)
            old_plan = sub_ref.activity_plan

            suffix = PLAN_MAP[old_plan.plan][:suffix] rescue nil
            next unless suffix

            p_name = "#{old_plan.activity.name.squish.titleize} - #{suffix}"
            product = Product.find_by(name: p_name)

            # Creazione di emergenza per prodotti mancanti
            unless product
               act_cat = "institutional"
               product = Product.create!(
                 name: p_name,
                 price_cents: (old_plan.cost.to_f * 100).to_i,
                 duration_days: PLAN_MAP[old_plan.plan][:days],
                 accounting_category: "institutional"
               )
               disc = Discipline.find_or_create_by(name: old_plan.activity.name.squish.titleize)
               ProductDiscipline.create!(product: product, discipline: disc)
               print "P" # Created Product
            end

            start_date, end_date = sub_ref.start_date, sub_ref.end_date
          end

          next unless product

          r_num, r_year = nil, nil

          if old_r = old_pay.receipt
            real = Source::ReceiptMembership.find_by(receipt_id: old_r.id) ||
                   Source::ReceiptSubscription.find_by(receipt_id: old_r.id)
            if real
              r_num, r_year = real.number, real.year
            end
          end

          r_num ||= (9000000 + old_pay.id)
          r_year ||= old_pay.created_at.year

          sale = Sale.new(
            member: member, user: admin, product: product,
            sold_on: old_pay.created_at.to_date,
            amount_cents: (old_pay.amount.to_f * 100).to_i,
            payment_method: PAYMENT_METHOD_MAP[old_pay.method] || :cash,
            receipt_number: r_num,
            receipt_year: r_year,
            receipt_sequence: product.accounting_category,
            notes: "Legacy Import ID #{old_pay.id}"
          )

          begin
            sale.save!
          rescue ActiveRecord::RecordNotUnique, SQLite3::ConstraintException
            # FIX PER DUPLICATI
            sale.receipt_number = 9000000 + old_pay.id
            sale.notes += " (CONFLICT)"
            sale.save!
            print "R"
          end

          Subscription.create!(
            member: member, product: product, sale: sale,
            start_date: start_date, end_date: end_date
          )
          print "."

        rescue => e
          print "X"
        end
      end
    end

    puts "\n🔄 Sync Contatori..."
    Sale.group(:receipt_year, :receipt_sequence).maximum(:receipt_number).each do |(y, s), max|
      next unless max
      ReceiptCounter.find_or_initialize_by(year: y, sequence_category: s).update!(last_number: max)
    end

    puts "\n🏁 FINITO TUTTO."
  end
end
