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

# incasso in contanti di un giorno contabile, diviso nei turni di mattina e pomeriggio
class DailyCash
  SPLIT_HOUR = 14

  attr_reader :date

  def self.for(date, sales: nil) = new(date, sales:)

  # sales: i pagamenti in contanti del giorno già caricati, per non rifare la query
  def initialize(date = Date.current, sales: nil)
    @date = date
    @sales = sales&.sort_by(&:created_at)
  end

  def sales
    @sales ||= Sale.kept.where(sold_on: date, payment_method: :cash).order(:created_at).to_a
  end

  def morning_sales   = registered_on_the_day.select { it.created_at < split_time }
  def afternoon_sales = registered_on_the_day.select { it.created_at >= split_time }

  # del giorno ma registrate un altro giorno (date retrodatate dall'admin): nel totale, in nessun turno
  def late_sales = sales.reject { registered_on_the_day?(it) }

  def morning_cents   = morning_sales.sum(&:amount_cents)
  def afternoon_cents = afternoon_sales.sum(&:amount_cents)
  def late_cents      = late_sales.sum(&:amount_cents)
  def total_cents     = sales.sum(&:amount_cents)

  def count  = sales.size
  def empty? = sales.empty?

  private
    def registered_on_the_day
      @registered_on_the_day ||= sales.select { registered_on_the_day?(it) }
    end

    def registered_on_the_day?(sale)
      sale.created_at.in_time_zone.to_date == date
    end

    def split_time
      @split_time ||= date.in_time_zone.change(hour: SPLIT_HOUR)
    end
end
