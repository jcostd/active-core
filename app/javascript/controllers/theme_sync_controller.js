import { Controller } from "@hotwired/stimulus"

// Turbo non aggiorna gli attributi di <html>: dopo un cambio tema ci pensa il body
export default class extends Controller {
  static values = { theme: String }

  themeValueChanged() {
    if (this.themeValue) document.documentElement.setAttribute("data-theme", this.themeValue)
  }
}
