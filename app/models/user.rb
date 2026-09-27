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
  after_discard :terminate_all_sessions

  has_many :sales, dependent: :restrict_with_error
  has_many :feedbacks, dependent: :restrict_with_error
  has_many :activity_logs, dependent: :restrict_with_error
  has_many :checkins_performed, class_name: "AccessLog",
           foreign_key: "checkin_by_user_id",
           dependent: :restrict_with_error

  enum :role, { staff: 0, admin: 1 }, default: :staff

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

  private
    def keep_an_admin
      return unless will_save_change_to_role? && role_in_database == "admin"
      return if User.kept.admin.where.not(id:).exists?

      errors.add(:role, "non può essere cambiato: serve almeno un amministratore")
    end

    def terminate_all_sessions
      sessions.delete_all
    end
end
