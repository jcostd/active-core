import { Controller } from "@hotwired/stimulus"

// Collegato a data-controller="flash"
export default class extends Controller {
	connect() {
		this.timeout = setTimeout(() => {
			this.dismiss()
		}, 5000)
	}

	disconnect() {
		clearTimeout(this.timeout)
	}

	dismiss() {
		this.element.classList.add(
			'opacity-0',
			'-translate-y-6',
			'transition-all',
			'duration-300',
			'ease-in'
		)
		setTimeout(() => {
			this.element.remove()
		}, 300)
	}
}
