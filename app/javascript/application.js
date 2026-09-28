// Import map in config/importmap.rb. Vedi https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// un aggiornamento in tempo reale non chiude la finestra in uso: POS in modale o cassetto dei filtri
addEventListener("turbo:before-morph-element", (event) => {
  const element = event.target
  const openDialog = element.matches("dialog[open]") || (element.matches("turbo-frame") && element.querySelector(":scope > dialog[open]"))

  if (openDialog) event.preventDefault()
})
