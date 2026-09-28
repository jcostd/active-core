# segnalazioni per lo sviluppatore: dello staff (bottone "Invia Feedback") o del sistema, senza utente
class Feedback < ApplicationRecord
  belongs_to :user, optional: true, touch: true

  validates :message, presence: true
end
