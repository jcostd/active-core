module Personable
  extend ActiveSupport::Concern

  included do
    normalizes :first_name, :last_name, with: ->(name) { ProperCase.person(name) }

    validates :first_name, :last_name, presence: true
  end
end
