# Correzione degli errori: lo staff annulla solo i propri pagamenti, l'admin qualsiasi.
module Sale::Reversible
  extend ActiveSupport::Concern

  ADMIN_REVERSAL_WINDOW = 24.hours
  STAFF_REVERSAL_WINDOW = 15.minutes

  def reversible_by?(user)
    return false if discarded? || !(user.admin? || user_id == user.id)

    created_at > (user.admin? ? ADMIN_REVERSAL_WINDOW : STAFF_REVERSAL_WINDOW).ago
  end
end
