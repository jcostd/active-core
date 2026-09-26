# Un corso si vende solo se la Quota Associativa copre il giorno in cui parte per il socio:
# l'inizio del corso, o la vendita se il corso è allineato a una data passata.
# Le rate pagano un diritto già venduto: il controllo è stato fatto allora.
module Sale::MembershipGuard
  extend ActiveSupport::Concern

  included do
    validate :membership_covers_course, on: :create
  end

  # corso che finisce oltre la quota: si vende lo stesso, ma lo staff va avvisato
  def membership_warning
    return unless course_sale? && subscription.end_date

    covered = member.membership_covered_until(membership_check_date)
    return if covered.nil? || covered >= subscription.end_date

    "Il corso termina il #{I18n.l(subscription.end_date)}, ma la Quota Associativa copre fino al " \
      "#{I18n.l(covered)}: il socio dovrà rinnovarla."
  end

  private
    def course_sale?
      product&.institutional? && member && subscription&.new_record? && subscription.start_date
    end

    def membership_check_date
      [ subscription.start_date, sold_on || Date.current ].max
    end

    def membership_covers_course
      return if !course_sale? || member.membership_valid?(membership_check_date)

      errors.add(:base, "Impossibile vendere #{product.name}: " \
                        "il socio non ha una Quota Associativa valida il #{I18n.l(membership_check_date)}.")
    end
end
