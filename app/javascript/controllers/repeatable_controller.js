import { Controller } from "@hotwired/stimulus"

// righe ripetibili di un form (gli atleti di una privata): se ne aggiunge una dal template, l'ultima si svuota invece di sparire
export default class extends Controller {
  static targets = ["list", "template", "row"]

  add() {
    this.listTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
    this.rowTargets.at(-1).querySelector("input").focus()
  }

  remove(event) {
    const row = event.target.closest("[data-repeatable-target=row]")

    if (this.rowTargets.length > 1) {
      row.remove()
    } else {
      const input = row.querySelector("input")
      input.value = ""
      input.focus()
    }
  }
}
