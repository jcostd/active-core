import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  // dopo un refresh di Turbo il cassetto aperto torna modale
  connect() {
    if (this.dialogTarget.hasAttribute("open")) {
      this.dialogTarget.removeAttribute("open")
      this.dialogTarget.showModal()
    }
  }

  disconnect() {
    if (this.dialogTarget.hasAttribute("open")) this.dialogTarget.close()
  }

  open(event) {
    event?.preventDefault()
    this.dialogTarget.showModal()
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }
}
