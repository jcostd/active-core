import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme-sync"
export default class extends Controller {
    static values = { theme: String }

    themeValueChanged() {
	if (this.themeValue) {
	    const htmlTag = document.documentElement;

	    htmlTag.setAttribute("data-theme", this.themeValue);
	    htmlTag.style.backgroundColor = "var(--fallback-b2,oklch(var(--b2)))";
	}
    }
}
