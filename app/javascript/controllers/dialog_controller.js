import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    this.element.showModal()

    this.boundRemove = this.element.remove.bind(this.element)
    document.addEventListener("turbo:before-cache", this.boundRemove, { once: true })
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.boundRemove)
  }

  close() {
    this.element.close()
  }

  // svuota il frame alla chiusura: lo stesso link potrà riaprire la modale
  cleanUp() {
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.innerHTML = ""
      frame.removeAttribute("src")
    }
  }
}
