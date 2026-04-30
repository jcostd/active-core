import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
    close(event) {
	if (this.element.open && !this.element.contains(event.target)) {
	    this.element.removeAttribute("open")
	}
    }

    closeOnEscape(event) {
	if (event.key === "Escape" && this.element.open) {
	    this.element.removeAttribute("open")
	}
    }
}
