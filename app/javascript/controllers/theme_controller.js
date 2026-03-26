// TODO delete
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
	connect() {
		this.load()
	}

	load() {
		fetch("/preferences/theme", {
			headers: { "Accept": "application/json" },
		})
			.then(response => response.json())
			.then(data => {
				if (data.theme) {
					document.documentElement.setAttribute("data-theme", data.theme)
				}
			})
	}

	change(event) {
		const theme = event.currentTarget.dataset.setTheme

		document.documentElement.setAttribute("data-theme", theme)

		fetch("/preferences/theme", {
			method: "PATCH",
			headers: {
				"Content-Type": "application/json",
				"Accept": "application/json",
				"X-CSRF-Token": this.csrfToken
			},
			credentials: 'same-origin',
			body: JSON.stringify({ theme })
		}).then(response => {
			if (response.ok) {
				console.log("Theme updated to:", theme)
				window.location.reload()
			}
		})
	}

	get csrfToken() {
		return document.querySelector('meta[name="csrf-token"]').content
	}
}
