import { Controller } from "@hotwired/stimulus"

// modale di daisyUI nel frame "modal": si apre da sola; si chiude con i form method="dialog"
// (✕, clic fuori, Esc) o dopo un salvataggio riuscito, e chiusa svuota il frame
export default class extends Controller {
  connect() {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    this.element.showModal()
  }

  close() {
    this.element.close()
  }

  // POST, PATCH o DELETE andati a buon fine: la pagina sotto si aggiorna da sola (refresh o redirect)
  closeAfterSave({ detail: { success, formSubmission } }) {
    if (success && !formSubmission.isSafe) this.close()
  }

  clear() {
    const frame = this.element.closest("turbo-frame")
    frame.removeAttribute("src")
    frame.replaceChildren()
  }
}
