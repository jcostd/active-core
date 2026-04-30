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

class SportYear
  attr_reader :year

  def initialize(date = Date.current)
    @date = date
    @year = (@date.month >= 9 ? @date.year : @date.year - 1)
  end

  def start_date
    Date.new(@year, 9, 1)
  end

  def end_date
    Date.new(@year + 1, 8, 31)
  end

  def range
    start_date..end_date
  end

  def to_s
    "#{@year}/#{@year + 1}"
  end

  def self.current
    new(Date.current)
  end

  def self.end_date_for(date)
    new(date).end_date
  end
end
