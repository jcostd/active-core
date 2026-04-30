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

class ReceiptCounter < ApplicationRecord
  validates :year, :sequence_category, presence: true

  def self.next_number(year, category)
    transaction do
      counter = create_or_find_by!(year: year, sequence_category: category)

      ReceiptCounter.update_counters(counter.id, last_number: 1)

      counter.reload.last_number
    end
  end
end
