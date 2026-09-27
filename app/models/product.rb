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

class Product < ApplicationRecord
  include SoftDeletable, Monetizable, Refreshable
  include Product::Filterable

  monetize :price

  has_many :product_disciplines, dependent: :destroy
  has_many :disciplines, through: :product_disciplines
  has_many :sales, dependent: :restrict_with_error
  has_many :subscriptions, dependent: :restrict_with_error

  enum :accounting_category, {
          institutional: "institutional",
          associative:   "associative"
        }, default: :institutional, validate: true

  normalizes :name, with: ->(name) { ProperCase.title(name) }

  validates :name, presence: true, uniqueness: { conditions: -> { kept }, case_sensitive: false }
  validates :duration_days, numericality: { greater_than: 0, only_integer: true }
  validates :price_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :terms_fixed_once_sold, on: :update

  # categoria e durata decidono date e validità degli abbonamenti già venduti: dopo la prima vendita non cambiano
  def terms_locked?
    persisted? && subscriptions.exists?
  end

  private
    def terms_fixed_once_sold
      return unless terms_locked?

      %i[accounting_category duration_days].select { will_save_change_to_attribute?(it) }.each do |attribute|
        errors.add(attribute, "non può essere cambiata: il prodotto ha già abbonamenti venduti")
      end
    end
end
