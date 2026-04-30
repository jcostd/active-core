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
