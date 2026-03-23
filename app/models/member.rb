class Member < ApplicationRecord
  include FtsSearchable, Filterable, SoftDeletable, Personable, HasAddress, Avatarable

  # --- NORMALIZATIONS ---
  normalizes :fiscal_code, with: ->(c) { c.strip.upcase }

  # --- ASSOCIATIONS ---
  has_many :sales, dependent: :restrict_with_error
  has_many :access_logs, dependent: :destroy
  has_many :subscriptions, dependent: :destroy

  # Associazione specifica per le quote associative (membership)
  has_many :memberships, -> { joins(:product).merge(Product.associative) },
           class_name: "Subscription"

  # --- VALIDATIONS ---
  validates :birth_date, presence: true

  validates :fiscal_code,
            presence: true,
            uniqueness: { conditions: -> { kept } },
            format: { with: /\A[A-Z0-9]{16}\z/, message: "must be 16 alphanumeric characters" }

  validates :phone, phone: { possible: true, allow_blank: true, types: [ :mobile, :fixed_line ] }

  # ==============================================================================
  # FILTERABLE CONFIGURATION
  # ==============================================================================

  def self.available_filters
    [
      { key: :query, label: "Cerca (Nome, CF, Email)" },
      {
        key: :membership_status,
        label: "Stato Tesseramento",
        options: [
          [ "In Regola (Attivo)", "active" ],
          [ "Scaduto", "expired" ],
          [ "Mai Tesserato (Prospect)", "missing" ]
        ]
      },
      {
        key: :med_cert,
        label: "Certificato Medico",
        options: [
          [ "Valido", "valid" ],
          [ "Scaduto", "expired" ],
          [ "Mancante", "missing" ]
        ]
      },
      {
        key: :state,
        label: "Archivio",
        options: [
          [ "Attivi", "active" ],
          [ "Archiviati", "archived" ]
        ]
      }
    ]
  end

  def self.available_sorts
    [
      { key: :last_name, label: "Cognome (A-Z)" },
      { key: :created_at, label: "Data Iscrizione" },
      { key: :medical_certificate_expiry, label: "Scadenza Cert. Medico" },
      { key: :birth_date, label: "Età / Data Nascita" }
    ]
  end

  # Default sorting se non specificato
  def self.default_sort_key; :last_name; end
  def self.default_sort_direction; :asc; end

  # ==============================================================================
  # SCOPES (IMPLEMENTATION)
  # ==============================================================================

  # 1. Ricerca Testuale
  scope :search_by_text, ->(text) {
    term = "%#{text.strip}%"
    where(
      "members.full_name LIKE :term OR members.fiscal_code LIKE :upcase_term OR members.email_address LIKE :term",
      term: term,
      upcase_term: term.upcase
    )
  }

  # 2. Filtro Stato Record (Soft Delete)
  scope :filter_by_state, ->(val) {
    val == "archived" ? discarded : kept
  }

  # 3. Filtro Certificato Medico
  scope :filter_by_med_cert, ->(val) {
    today = Date.current
    case val
    when "valid"
      where("members.medical_certificate_expiry >= ?", today)
    when "expired"
      where("members.medical_certificate_expiry < ?", today)
    when "missing"
      where(members: { medical_certificate_expiry: nil })
    end
  }

  # 4. Filtro Membership (COMPLESSO)
  # Usa joins espliciti per evitare ambiguità e garantisce performance
  scope :filter_by_membership_status, ->(val) {
    today = Date.current
    case val
    when "active"
      # Utenti che hanno ALMENO una subscription di tipo associativo che scade nel futuro
      joins(:memberships)
        .where("subscriptions.end_date >= ?", today)
        .distinct
    when "missing"
      # Utenti che NON hanno mai avuto una subscription associativa (Rails 6.1+ where.missing)
      where.missing(:memberships)
    when "expired"
      # Utenti che hanno memberships MA la cui data massima di fine è nel passato.
      # Usiamo una subquery EXISTS per pulizia o HAVING. Qui approccio HAVING per chiarezza:
      joins(:memberships)
        .group("members.id")
        .having("MAX(subscriptions.end_date) < ?", today)
    end
  }

  # 5. Ordinamenti Custom (NULLS LAST)
  scope :sort_by_medical_certificate_expiry, ->(dir) {
    # Sanitizziamo la direzione
    direction = dir.to_s.downcase == "desc" ? :desc : :asc

    # Costruiamo la query con Arel
    order(arel_table[:medical_certificate_expiry].send(direction).nulls_last)
  }

  # ==============================================================================
  # INSTANCE METHODS
  # ==============================================================================

  def medical_certificate_valid?(date = Date.today)
    return false if medical_certificate_expiry.nil?
    medical_certificate_expiry >= date
  end

  def membership_expiry_date
    # Usa kept per evitare di contare abbonamenti cancellati per errore
    memberships.kept.maximum(:end_date)
  end

  def membership_valid?(date = Date.today)
    expiry = membership_expiry_date
    return false if expiry.nil?
    expiry >= date
  end

  def compliant?(date = Date.today)
    medical_certificate_valid?(date) && membership_valid?(date)
  end

  def status_label
    return "error" if discarded?
    return "warning" unless compliant?
    "success"
  end

  def relevant_subscriptions
    # Carica le associazioni se non sono già caricate per evitare N+1
    source = subscriptions.loaded? ? subscriptions : subscriptions.includes(:product)

    # Filtra in memoria per velocità se già caricati
    active_source = source.select { |sub| sub.kept? }

    # Ordina per data decrescente
    sorted = active_source.sort_by(&:end_date).reverse

    # Prendi l'ultimo per ogni prodotto
    latest_per_product = sorted.uniq(&:product_id)

    # Mostra solo quelli recenti (es. scaduti da meno di 60gg o futuri)
    cutoff_date = 60.days.ago.to_date
    visible = latest_per_product.select do |sub|
      sub.end_date >= cutoff_date
    end

    # Ordina visivamente per scadenza imminente
    visible.sort_by { |sub| (sub.end_date - Date.current).to_i }
  end

  def renewal_info_for(product)
    dates = RenewalCalculator.new(self, product, Date.current).call

    # Query specifica e ottimizzata
    last_sub = subscriptions.kept
                            .where(product_id: product.id)
                            .order(end_date: :desc)
                            .first

    dates.merge(last_subscription_end: last_sub&.end_date)
  end
end
