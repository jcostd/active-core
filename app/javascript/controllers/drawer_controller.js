import { Controller } from "@hotwired/stimulus"

// cassetto dei filtri: finché è aperto è permanente, così un aggiornamento in tempo reale non lo chiude
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event?.preventDefault()
    this.dialogTarget.setAttribute("data-turbo-permanent", "")
    this.dialogTarget.showModal()
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }

  closed() {
    this.dialogTarget.removeAttribute("data-turbo-permanent")
  }
}
