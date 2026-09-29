module SoftDeletable
  extend ActiveSupport::Concern

  included do
    define_model_callbacks :discard, :undiscard

    scope :kept, -> { where(discarded_at: nil) }
    scope :discarded, -> { where.not(discarded_at: nil) }
  end

  def discarded?
    discarded_at.present?
  end

  def kept?
    !discarded?
  end

  # atomico: se un callback abortisce, solleva e annulla l'intera cascata
  def discard!
    transaction do
      run_callbacks(:discard) { touch(:discarded_at) } || raise(ActiveRecord::RecordNotSaved.new("archiviazione annullata", self))
    end
  end

  def undiscard!
    transaction do
      run_callbacks(:undiscard) { update!(discarded_at: nil) } || raise(ActiveRecord::RecordNotSaved.new("ripristino annullato", self))
    end
  end
end
