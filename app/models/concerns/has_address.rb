module HasAddress
  extend ActiveSupport::Concern

  included do
    normalizes :city, :address, with: ->(place) { ProperCase.place(place) }
    normalizes :zip_code, with: ->(val) { val&.strip&.gsub(/\D/, "") }
  end
end
