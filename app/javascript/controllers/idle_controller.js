import { Controller } from "@hotwired/stimulus"

// Esce dopo timeoutValue secondi senza input dell'utente, inviando il form di uscita della pagina.
// L'ultima attività è condivisa tra le schede via localStorage.
const STORAGE_KEY = "idle:last-activity"
const EVENTS = [ "pointerdown", "keydown", "wheel", "touchstart" ]
const CHECK_EVERY_MS = 15_000
const WRITE_EVERY_MS = 5_000

export default class extends Controller {
  static targets = [ "signOut" ]
  static values = { timeout: Number }

  connect() {
    this.record = this.record.bind(this)
    EVENTS.forEach(event => window.addEventListener(event, this.record, { passive: true }))
    this.record()
    this.timer = setInterval(() => this.check(), CHECK_EVERY_MS)
  }

  disconnect() {
    EVENTS.forEach(event => window.removeEventListener(event, this.record))
    clearInterval(this.timer)
  }

  record() {
    const now = Date.now()
    if (this.last && now - this.last < WRITE_EVERY_MS) return

    this.last = now
    try { localStorage.setItem(STORAGE_KEY, String(now)) } catch {}
  }

  check() {
    if (Date.now() - this.lastActivity() < this.timeoutValue * 1000) return

    clearInterval(this.timer)
    this.signOut()
  }

  lastActivity() {
    let shared = 0
    try { shared = Number(localStorage.getItem(STORAGE_KEY)) || 0 } catch {}
    return Math.max(shared, this.last || 0)
  }

  signOut() {
    this.signOutTarget.requestSubmit()
  }
}
