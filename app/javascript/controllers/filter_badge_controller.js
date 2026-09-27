import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  remove(event) {
    const key = event.params.key
    const form = this.form
    if (!form || !key) return

    const input = form.querySelector(`[name="${key}"]`) || form.querySelector(`[name$="[${key}]"]`)
    if (!input) return

    clear(input)
    form.requestSubmit()
  }

  clearAll(event) {
    event.preventDefault()
    const form = this.form
    if (!form) return

    form.querySelectorAll('input:not([type="hidden"]), select:not([name="sort"]), textarea').forEach(clear)
    form.requestSubmit()
  }

  get form() {
    return document.getElementById("filter-form")
  }
}

function clear(input) {
  if (input.type === "checkbox" || input.type === "radio") {
    input.checked = false
  } else {
    input.value = ""
  }
}
