import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["content", "input"]

    toggle(event) {
	if (event.target.checked) {
	    this.contentTarget.classList.remove("hidden")
	} else {
	    this.contentTarget.classList.add("hidden")
	    if (this.hasInputTarget) {
		this.inputTarget.value = ""
	    }
	}
    }
}
