# app/models/access_policy.rb
class AccessPolicy
  include ActiveModel::Model

  attr_accessor :member, :discipline
  attr_reader :subscription, :warnings

  validate :check_membership
  validate :check_subscription
  validate :check_entry_limits

  def initialize(attributes = {})
    super
    @warnings = []
    @subscription = member.valid_subscription_for(discipline)
  end

  def evaluate!
    valid?
    evaluate_warnings if errors.empty?
    self
  end

  def granted?
    errors.empty?
  end

  def status
    return :error if errors.any?
    return :warning if warnings.any?
    :ok
  end

  private
    def check_membership
      if discipline.requires_membership? && !member.membership_valid?
        errors.add(:base, "Quota Associativa scaduta o mancante.")
      end
    end

    def check_subscription
      unless subscription
        errors.add(:base, "Nessun abbonamento attivo per '#{discipline.name}'.")
      end
    end

    def check_entry_limits
      return unless subscription && entry_limit_applies?

      # Nota: qui diamo per scontato che tu abbia access_logs_count o un metodo simile in Subscription
      used_entries = subscription.access_logs.valid_entries.count
      if used_entries >= subscription.entry_limit
        errors.add(:base, "Ingressi esauriti (#{used_entries}/#{subscription.entry_limit}).")
      end
    end

    def evaluate_warnings
      if discipline.requires_medical_certificate? && !member.medical_certificate_valid?
        @warnings << "Certificato Medico scaduto o mancante."
      end

      if subscription_expiring_soon?
        days_left = (subscription.end_date - Date.current).to_i
        @warnings << "Abbonamento in scadenza tra #{days_left} giorni."
      end

      if entry_limit_applies?
        used = subscription.access_logs.valid_entries.count
        remaining = subscription.entry_limit - used
        if remaining <= 2
          @warnings << "Rimangono solo #{remaining} ingressi."
        end
      end
    end

    # --- Metodi Helper Interni ---

    def entry_limit_applies?
      subscription.entry_limit.present? && subscription.entry_limit > 0
    end

    def subscription_expiring_soon?
      return false unless subscription.end_date
      subscription.end_date <= 7.days.from_now.to_date
    end
end
