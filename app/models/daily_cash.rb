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

  # Aggiungiamo 'stats' come parametro per i totali pre-calcolati da SQL
  def initialize(date = Date.current, sales: nil, stats: nil)
    @date = date
    @preloaded_sales = sales
    @stats = stats # Hash: { morning: 0, afternoon: 0, total: 0 }
  end

  def self.current
    new(Date.current)
  end

  def self.for(date, sales: nil, stats: nil)
    new(date, sales: sales, stats: stats)
  end

  # --- API ---

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
    # 1. Se abbiamo le statistiche da SQL, usiamo il numero istantaneamente!
    return @stats[:count] if @stats

    # 2. Se abbiamo i record in memoria (azione show), contiamo l'array
    return @preloaded_sales.size if @preloaded_sales

    # 3. Fallback: query singola al DB
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
    # 1. Se abbiamo i totali da SQL (azione index) usa quelli istantaneamente
    return @stats[:morning] if @stats

    # 2. Se abbiamo i record in RAM (azione show) calcola in Ruby
    if @preloaded_sales
      return @preloaded_sales.select { |s| s.created_at < split_time }.sum(&:amount_cents)
    end

    # 3. Fallback: calcolo SQL puro per un singolo giorno isolato
    @morning_cents ||= base_scope.where("created_at < ?", split_time).sum(:amount_cents)
  end

  def afternoon_cents
    return @stats[:afternoon] if @stats

    if @preloaded_sales
      return @preloaded_sales.select { |s| s.created_at >= split_time }.sum(&:amount_cents)
    end

    @afternoon_cents ||= base_scope.where("created_at >= ?", split_time).sum(:amount_cents)
  end

  def total_cents
    return @stats[:total] if @stats
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
