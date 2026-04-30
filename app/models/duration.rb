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

Duration = Data.define(:start_date, :end_date) do
  CALENDAR_DURATIONS = {
    30  => 1,
    90  => 3,
    180 => 6,
    365 => 12,
    366 => 12
  }.freeze

  def self.for(product, preference_date = Date.current)
    new(**calculate(product, preference_date.to_date))
  end

  private_class_method def self.calculate(product, date)
    product.associative? ? associative(date) : institutional(product, date)
  end

  private_class_method def self.associative(date)
    { start_date: date, end_date: SportYear.end_date_for(date) }
  end

  private_class_method def self.institutional(product, date)
    case product.duration_days
    when 365, 366 then rolling_annual(date)
    when 90       then calendar_aligned(date, 3, enforce_sport_year: false)
    else
      months = CALENDAR_DURATIONS[product.duration_days]
      months ? calendar_aligned(date, months) : days_pure(product, date)
    end
  end

  private_class_method def self.rolling_annual(date)
    { start_date: date, end_date: date.advance(years: 1).yesterday }
  end

  private_class_method def self.calendar_aligned(date, months, enforce_sport_year: true)
    start_date      = date.beginning_of_month
    theoretical_end = start_date.advance(months: months - 1).end_of_month
    end_date        = enforce_sport_year ?
                        [ theoretical_end, SportYear.end_date_for(start_date) ].min :
                        theoretical_end
    { start_date:, end_date: }
  end

  private_class_method def self.days_pure(product, date, enforce_sport_year: true)
    theoretical_end = date.advance(days: product.duration_days).yesterday
    end_date        = enforce_sport_year ?
                        [ theoretical_end, SportYear.end_date_for(date) ].min :
                        theoretical_end
    { start_date: date, end_date: }
  end
end
