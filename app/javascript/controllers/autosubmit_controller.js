import { Controller } from "@hotwired/stimulus"
import { debounce } from "utils/debounce"

// Connects to data-controller="autosubmit"
export default class extends Controller {
    connect() {
        this.submitHandler = debounce(this.submitHandler.bind(this), 300)
    }

    submit(event) {
	const clearSelector = event.params?.clear

	if (clearSelector) {
	    document.querySelectorAll(clearSelector).forEach(element => {
		element.value = ""
	    })
	}

	this.submitHandler()
    }

    prevent(event) {
        event.preventDefault()
    }

    submitHandler() {
        if (this.element.tagName === "FORM") {
            this.element.requestSubmit()
            return
        }

        const input = this.element
        const frameId = input.dataset.frameId
        const urlString = input.dataset.url
        const query = input.value.trim()

        if (!frameId || !urlString) return

        const frame = document.getElementById(frameId)

        if (query.length < 2) {
            if (frame) {
                frame.innerHTML = ""
                frame.removeAttribute("src")
            }
            return
        }

        const url = new URL(urlString, window.location.origin)
        url.searchParams.set("query", query)
        url.searchParams.set("frame_id", frameId)

        if (frame) {
            frame.src = url.toString()
        }
    }
}
