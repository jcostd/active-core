import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "hidden", "frame"]

    connect() {
	this.clickOutsideHandler = this.clickOutside.bind(this)
	document.addEventListener("click", this.clickOutsideHandler)
    }

    disconnect() {
	document.removeEventListener("click", this.clickOutsideHandler)
    }

    select(event) {
	event.preventDefault()

	// 1. Estraiamo i dati dal bottone cliccato
	const button = event.currentTarget
	const id = button.dataset.id
	const name = button.dataset.name

	// 2. Aggiorniamo i campi
	this.hiddenTarget.value = id
	this.inputTarget.value = name

	// 3. Chiudiamo la tendina (svuotando il frame)
	this.closeFrame()

	// 4. UX: Togliamo il focus dall'input (ottimo per nascondere la tastiera su mobile)
	this.inputTarget.blur()

	// 5. IL TOCCO MAGICO: Inneschiamo l'autosubmit!
	// Lanciamo un evento 'change' sul campo nascosto, che verrà intercettato da autosubmit
	this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    clearIfEmpty() {
	if (this.inputTarget.value.trim() === "") {

	    if (this.hiddenTarget.value !== "") {
		this.hiddenTarget.value = ""
		this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
	    }

	    this.closeFrame()
	}
    }

    closeFrame() {
	if (this.hasFrameTarget) {
	    this.frameTarget.innerHTML = ""
	    this.frameTarget.removeAttribute("src")
	}
    }

    clickOutside(event) {
	if (!this.element.contains(event.target)) {
	    this.closeFrame()
	}
    }
}
