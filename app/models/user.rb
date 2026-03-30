class User < ApplicationRecord
  include SoftDeletable, Personable, UserPreferences, Avatarable

  broadcasts_refreshes

  has_secure_password
  has_many :sessions, dependent: :destroy

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
                       format: { with: /\A[a-z0-9_]+\z/, message: "only allows lowercase letters, numbers and underscores" }

  validates :password, length: { minimum: 4 }, allow_nil: true

  scope :search_text, ->(query) {
    term = "%#{query}%"
    where(
      "first_name LIKE :term OR last_name LIKE :term OR email_address LIKE :term OR username LIKE :term",
      term: term
    )
  }
end
