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

class DailyCash
  SPLIT_HOUR = 14
  attr_reader :date

  # sales: pagamenti già caricati (evita query), altrimenti li legge dal database
  def initialize(date = Date.current, sales: nil)
    @date = date
    @preloaded_sales = sales
  end

  def self.current
    new(Date.current)
  end

  def self.for(date, sales: nil)
    new(date, sales:)
  end

  # --- INTERFACCIA PUBBLICA ---

  def morning_total
    to_currency(morning_cents)
  end

  def afternoon_total
    to_currency(afternoon_cents)
  end

  def total
    to_currency(total_cents)
  end

  def count
    return @preloaded_sales.size if @preloaded_sales

    base_scope.count
  end

  def empty?
    count.zero?
  end

  def morning_sales
    return filter_sales_in_memory { |s| s.created_at < split_time } if @preloaded_sales
    base_scope.where("created_at < ?", split_time).order(:created_at)
  end

  def afternoon_sales
    return filter_sales_in_memory { |s| s.created_at >= split_time } if @preloaded_sales
    base_scope.where("created_at >= ?", split_time).order(:created_at)
  end

  # --- LOGICA DI AGGREGAZIONE MIGLIORATA ---

  def morning_cents
    if @preloaded_sales
      return @preloaded_sales.select { |s| s.created_at < split_time }.sum(&:amount_cents)
    end

    @morning_cents ||= base_scope.where("created_at < ?", split_time).sum(:amount_cents)
  end

  def afternoon_cents
    if @preloaded_sales
      return @preloaded_sales.select { |s| s.created_at >= split_time }.sum(&:amount_cents)
    end

    @afternoon_cents ||= base_scope.where("created_at >= ?", split_time).sum(:amount_cents)
  end

  def total_cents
    morning_cents + afternoon_cents
  end

  private

  def base_scope
    Sale.kept.where(sold_on: @date, payment_method: :cash)
  end

  def split_time
    @split_time ||= @date.in_time_zone.change(hour: SPLIT_HOUR, min: 0, sec: 0)
  end

  def to_currency(cents)
    return 0.0 unless cents
    cents / 100.0
  end

  def filter_sales_in_memory(&block)
    @preloaded_sales.select(&block).sort_by(&:created_at)
  end
end
