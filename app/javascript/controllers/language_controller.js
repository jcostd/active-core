// TODO delete
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="language"
export default class extends Controller {
	change(event) {
		const language = event.currentTarget.dataset.setLanguage

		fetch("/preferences/language", {
			method: "PATCH",
			headers: {
				"Content-Type": "application/json",
				"Accept": "application/json",
				"X-CSRF-Token": this.csrfToken
			},
			credentials: 'same-origin',
			body: JSON.stringify({ language })
		}).then(response => {
			if (response.ok) {
				window.location.reload()
			}
		})
	}

	get csrfToken() {
		return document.querySelector('meta[name="csrf-token"]').content
	}
}
