import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configurazione di Stimulus per lo sviluppo
application.debug = false
window.Stimulus   = application

export { application }
