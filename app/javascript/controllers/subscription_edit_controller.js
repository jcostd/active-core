// TODO delete
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
	static targets = ["startDate", "endDate", "status"]
	static values = {
		memberId: String,
		productId: String
	}

	// Quando l'utente cambia la data di inizio
	async refreshEndDate(event) {
		const newStartDate = this.startDateTarget.value

		// Se la data è vuota, non facciamo nulla
		if (!newStartDate) return

		this.setStatus("Calcolo...", "opacity-50")

		// Costruiamo l'URL chiamando lo stesso endpoint che usavi nella vendita
		// Passiamo ref_date = data inserita manualmente
		const url = `/members/${this.memberIdValue}/renewal_info?product_id=${this.productIdValue}&ref_date=${newStartDate}`

		try {
			const response = await fetch(url, {
				headers: { "Accept": "application/json" }
			})

			if (response.ok) {
				const data = await response.json()

				// Aggiorniamo la data di fine con quella calcolata dal server (Duration.rb)
				if (this.hasEndDateTarget && data.end_date) {
					this.endDateTarget.value = data.end_date

					// Flash verde per feedback visivo
					this.endDateTarget.classList.add("input-success")
					setTimeout(() => this.endDateTarget.classList.remove("input-success"), 1000)
				}

				this.setStatus("Data fine ricalcolata", "text-success")
			}
		} catch (error) {
			console.error(error)
			this.setStatus("Errore calcolo", "text-error")
		}
	}

	setStatus(text, classes) {
		if (this.hasStatusTarget) {
			this.statusTarget.textContent = text
			this.statusTarget.className = `label-text-alt ${classes}`
		}
	}
}
