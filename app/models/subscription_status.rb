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

# due dimensioni distinte: il periodo (key) e il pagamento (payment_key).
# Uno scaduto non saldato è "Scaduto" con un insoluto, non "Da saldare" per sempre.
class SubscriptionStatus
  attr_reader :subscription

  def initialize(subscription)
    @subscription = subscription
  end

  def key
    if subscription.expired?
      :expired
    elsif subscription.future?
      :future
    elsif subscription.expiring_soon? && !subscription.renewed?
      :expiring_soon
    else
      :active
    end
  end

  def label
    case key
    when :expired       then "Scaduto"
    when :future        then "Futuro"
    when :expiring_soon then "In Scadenza"
    when :active        then "Attivo"
    end
  end

  def payment_key
    if subscription.fully_paid?
      :paid
    else
      subscription.expired? ? :overdue : :due
    end
  end

  def payment_label
    case payment_key
    when :paid    then "Saldato"
    when :due     then "Da saldare"
    when :overdue then "Insoluto"
    end
  end
end
