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

class SubscriptionStatus
  attr_reader :subscription

  def initialize(subscription)
    @subscription = subscription
  end

  def requires_attention?
    [ :pending_payment, :expired, :expiring_soon, :out_of_entries ].include?(key)
  end

  def key
    if !subscription.fully_paid?
      :pending_payment
    elsif subscription.expired? || subscription.out_of_entries?
      :expired
    elsif subscription.future?
      :future
    elsif subscription.expiring_soon?
      :expiring_soon
    else
      :active
    end
  end

  def label
    case key
    when :pending_payment then "Da Saldare"
    when :expired         then "Scaduto"
    when :future          then "Futuro"
    when :expiring_soon   then "In Scadenza"
    when :active          then "Attivo"
    end
  end

  def color
    case key
    when :pending_payment then "error"
    when :expired         then "neutral"
    when :future          then "info"
    when :expiring_soon   then "warning"
    when :active          then "success"
    end
  end

  def icon
    case key
    when :pending_payment then "payments"
    when :expired         then "history"
    when :future          then "calendar_today"
    when :expiring_soon   then "notification_important"
    when :active          then "success"
    end
  end
end
