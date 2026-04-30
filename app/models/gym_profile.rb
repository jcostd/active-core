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

class GymProfile < ApplicationRecord
  validates :name, presence: true

  def self.current
    first_or_create!(name: "ActiveCore Gym")
  end

  def full_address
    [ address_line_1, address_line_2, "#{zip_code} #{city}".squish.presence ]
      .compact_blank
      .join(" - ")
  end
end
