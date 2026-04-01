module Personable
  extend ActiveSupport::Concern

  included do
    normalizes :email_address, with: ->(e) { e.strip.downcase }

    normalizes :first_name, :last_name, with: ->(s) { s.squish.titleize }

    validates :first_name, :last_name, presence: true
    validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  end
end
