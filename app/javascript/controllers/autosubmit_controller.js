import { Controller } from "@hotwired/stimulus"
import { debounce } from "utils/debounce"

export default class extends Controller {
    connect() {
        this.submitHandler = debounce(this.submitForm.bind(this), 300)
    }

    submit(event) {
        this.submitHandler()
    }

    submitForm() {
        this.element.requestSubmit()
    }
}
