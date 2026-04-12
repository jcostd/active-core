import { Controller } from "@hotwired/stimulus"
import { debounce } from "utils/debounce"

export default class extends Controller {
    static targets = ["input", "hidden", "frame"]

    connect() {
        this.performSearch = debounce(this.performSearch.bind(this), 300)
    }

    search() {
        this.performSearch()
    }

    performSearch() {
        const query = this.inputTarget.value.trim()
        const urlString = this.inputTarget.dataset.url

        if (!urlString) return

        if (query.length < 2) {
            this.closeFrame()
            return
        }

        const url = new URL(urlString, window.location.origin)
        url.searchParams.set("query", query)

        if (this.hasFrameTarget) {
            url.searchParams.set("frame_id", this.frameTarget.id)
            this.frameTarget.src = url.toString()
        }
    }

    select(event) {
        event.preventDefault()

        const button = event.currentTarget
        this.inputTarget.value = button.dataset.name

        if (this.hasHiddenTarget) {
            this.hiddenTarget.value = button.dataset.id
            this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
        }

        this.closeFrame()
        this.inputTarget.blur()
    }

    clearIfEmpty() {
        if (this.inputTarget.value.trim() === "") {
            if (this.hasHiddenTarget && this.hiddenTarget.value !== "") {
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
