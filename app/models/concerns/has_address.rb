module HasAddress
  extend ActiveSupport::Concern

  included do
    normalizes :city, :address, with: ->(val) { val&.strip&.titleize }
    normalizes :zip_code, with: ->(val) { val&.strip&.gsub(/\D/, "") }
  end
end
