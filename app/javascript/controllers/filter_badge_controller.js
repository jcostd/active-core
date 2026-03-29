import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter-badge"
export default class extends Controller {
    remove(event) {
	const key = event.params.key

	const form = document.getElementById("filter-form")
	if (!form || !key) return

	const input = form.querySelector(`[name="${key}"]`) || form.querySelector(`[name$="[${key}]"]`)

	if (input) {
	    input.value = ""
	    form.requestSubmit()
	}
    }

    clearAll(event) {
	event.preventDefault()
	const form = document.getElementById("filter-form")
	if (!form) return

	form.reset()
	form.requestSubmit()
    }
}
