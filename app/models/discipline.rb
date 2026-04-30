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

class Discipline < ApplicationRecord
  include SoftDeletable
  include Refreshable
  include Discipline::Filterable

  has_many :product_disciplines, dependent: :destroy
  has_many :products, through: :product_disciplines

  has_many :subscriptions, through: :products

  has_many :access_logs, dependent: :nullify

  normalizes :name, with: ->(n) { n.squish.titleize }
  validates :name, presence: true, uniqueness: { conditions: -> { kept } }

  def recent_subscriptions
    subscriptions
      .kept
      .where("subscriptions.end_date >= ?", 30.days.ago)
      .includes(:member, :product)
  end
end
