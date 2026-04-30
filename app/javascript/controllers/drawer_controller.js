import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drawer"
export default class extends Controller {
    static targets = ["dialog"]

    connect() {
	if (this.dialogTarget.hasAttribute("open")) {
	    this.dialogTarget.removeAttribute("open")
	    this.dialogTarget.showModal()
	}
    }

    disconnect() {
	if (this.dialogTarget.hasAttribute("open")) {
	    this.dialogTarget.close()
	}
    }

    open(event) {
	if (event) event.preventDefault()
	this.dialogTarget.showModal()
    }

    close(event) {
	if (event) event.preventDefault()
	this.dialogTarget.close()
    }

    clickOutside(event) {
	if (event.target === this.dialogTarget) {
	    this.close()
	}
    }
}
