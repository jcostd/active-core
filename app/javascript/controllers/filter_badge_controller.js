import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter-badge"
export default class extends Controller {
    remove(event) {
	const key = event.params.key
	const form = document.getElementById("filter-form")
	if (!form || !key) return

	const input = form.querySelector(`[name="${key}"]`) || form.querySelector(`[name$="[${key}]"]`)

	if (input) {
	    if (input.type === 'checkbox' || input.type === 'radio') {
		input.checked = false
	    } else {
		input.value = ""
	    }
	    form.requestSubmit()
	}
    }

    clearAll(event) {
	event.preventDefault()
	const form = document.getElementById("filter-form")
	if (!form) return

	const inputs = form.querySelectorAll('input:not([type="hidden"]), select:not([name="sort"]), textarea')

	inputs.forEach(input => {
	    if (input.type === 'checkbox' || input.type === 'radio') {
		input.checked = false
	    } else {
		input.value = ""
	    }
	})

	form.requestSubmit()
    }
}
