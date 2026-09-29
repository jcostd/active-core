class ReceiptCounter < ApplicationRecord
  validates :year, :sequence_category, presence: true
  validates :last_number, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.next_number(year, category)
    transaction do
      counter = create_or_find_by!(year: year, sequence_category: category)

      ReceiptCounter.update_counters(counter.id, last_number: 1)

      counter.reload.last_number
    end
  end
end
