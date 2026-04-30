# Copyright (C) 2026 Jacopo Costantini <jacopocostantini32@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

class AccessPolicy
  include ActiveModel::Model

  attr_accessor :member, :discipline
  attr_reader :subscription, :warnings

  validate :check_membership
  validate :check_subscription

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

    def evaluate_warnings
      if discipline.requires_medical_certificate? && !member.medical_certificate_valid?
        @warnings << "Certificato Medico scaduto o mancante."
      end

      if subscription_expiring_soon?
        days_left = (subscription.end_date - Date.current).to_i
        @warnings << "Abbonamento in scadenza tra #{days_left} giorni."
      end

      if entry_limit_applies? && subscription.entries_remaining <= 2
        @warnings << "Rimangono solo #{subscription.entries_remaining} ingressi."
      end
    end

    def entry_limit_applies?
      subscription&.entry_limit.present? && subscription.entry_limit > 0
    end

    def subscription_expiring_soon?
      return false unless subscription.end_date
      subscription.end_date <= 7.days.from_now.to_date
    end
end
