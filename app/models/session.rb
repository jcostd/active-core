class Session < ApplicationRecord
  belongs_to :user, touch: true

  def self.sweep(duration = 30.days)
    where(updated_at: ...duration.ago).delete_all
  end
end
