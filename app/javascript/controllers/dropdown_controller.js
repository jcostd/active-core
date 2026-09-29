import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  close(event) {
    if (this.element.open && !this.element.contains(event.target)) this.element.removeAttribute("open")
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && this.element.open) this.element.removeAttribute("open")
  }
}
