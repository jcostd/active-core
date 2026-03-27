class Subscription < ApplicationRecord
  include SoftDeletable, DateRangeable

  belongs_to :member
  belongs_to :product
  belongs_to :sale, inverse_of: :subscription

  validates :member, :product, :sale, presence: true

  # Il nuovo cuore automatico: scatta sempre prima di salvare un nuovo record
  before_validation :apply_business_rules, on: :create

  # Lo usiamo in Sale#prepare_draft per pre-compilare il form per la UI
  def assign_smart_dates(manual_start_date: nil)
    self.start_date = manual_start_date if manual_start_date.present?
    apply_business_rules
  end

  private
    def apply_business_rules
      return unless product.present? && member.present?

      # REGOLA 1 (Override Admin): Se la data di fine è già compilata,
      # l'Admin ha forzato la data. Il sistema si ferma e non tocca le date.
      return if end_date.present?

      # REGOLA 2 (Smart Renewal / Start Date Staff):
      # Se non abbiamo una start_date, calcoliamo il rinnovo intelligente.
      # Se lo Staff ne ha forzata una (es. 1° mese prossimo), usiamo la sua.
      if start_date.blank?
        reference_date = sale&.sold_on || Date.current
        self.start_date = RenewalCalculator.new(member, product, reference_date).call
      end

      # REGOLA 3 (Duration & Snap):
      # Passiamo la start_date a Duration per calcolare la scadenza e
      # applicare lo "snap" al 1° del mese (per i prodotti mensili/trimestrali).
      result = Duration.new(product, start_date).calculate

      self.start_date = result[:start_date]
      self.end_date   = result[:end_date]
    end
end
