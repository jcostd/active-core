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

class User < ApplicationRecord
  include SoftDeletable, Personable, UserPreferences, Avatarable
  include Refreshable
  include User::Filterable

  has_secure_password
  has_many :sessions, dependent: :destroy
  before_discard :keep_kiosk
  after_discard :terminate_all_sessions

  has_many :sales, dependent: :restrict_with_error
  has_many :feedbacks, dependent: :restrict_with_error
  has_many :marked_attendances, class_name: "Attendance", foreign_key: "marked_by_id", dependent: :restrict_with_error

  # kiosk: l'utente fisso dell'iPad, vede solo il kiosk
  enum :role, { staff: 0, admin: 1, kiosk: 2 }, default: :staff, validate: true
  ASSIGNABLE_ROLES = %w[staff admin].freeze

  scope :operators, -> { where.not(role: :kiosk) }

  normalizes :username, with: ->(u) { u.strip.downcase }
  validates :username, presence: true,
                       uniqueness: { conditions: -> { kept } },
                       format: { with: /\A[a-z0-9_]+\z/, message: "può contenere solo lettere minuscole, numeri e underscore" }

  # l'indice unico del database vale solo per gli utenti attivi
  validates :email_address, presence: true, uniqueness: { conditions: -> { kept }, case_sensitive: false }
  validates :password, length: { minimum: 4 }, allow_nil: true
  # has_secure_password ignora una password vuota: nel reset va pretesa
  validates :password, presence: true, on: :password_reset
  validate :keep_an_admin, on: :update
  validate :kiosk_role_is_fixed

  def archivable_by?(user)
    user.admin? && user != self && !kiosk? && kept?
  end

  private
    def keep_an_admin
      return unless will_save_change_to_role? && role_in_database == "admin"
      return if User.kept.admin.where.not(id:).exists?

      errors.add(:role, "non può essere cambiato: serve almeno un amministratore")
    end

    # unico e fisso: nessuno diventa kiosk e il kiosk non cambia ruolo
    def kiosk_role_is_fixed
      return unless will_save_change_to_role?
      return unless role_in_database == "kiosk" || (kiosk? && User.kept.kiosk.where.not(id:).exists?)

      errors.add(:role, "non può essere cambiato: l'utente kiosk è unico e fisso")
    end

    def keep_kiosk
      throw :abort if kiosk?
    end

    def terminate_all_sessions
      sessions.delete_all
    end
end
