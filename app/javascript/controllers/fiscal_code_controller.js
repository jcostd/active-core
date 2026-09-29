import { Controller } from "@hotwired/stimulus"

// omocodia: le cifre possono essere sostituite da lettere (L=0 ... V=9)
const OMOCODIA = { L: "0", M: "1", N: "2", P: "3", Q: "4", R: "5", S: "6", T: "7", U: "8", V: "9" }
const MONTHS = { A: "01", B: "02", C: "03", D: "04", E: "05", H: "06", L: "07", M: "08", P: "09", R: "10", S: "11", T: "12" }
const digits = (text) => text.replace(/[LMNPQRSTUV]/g, (letter) => OMOCODIA[letter])

// ricava la data di nascita dal codice fiscale mentre lo si scrive
export default class extends Controller {
  static targets = ["code", "birthDate"]

  autofill() {
    this.codeTarget.value = this.codeTarget.value.toUpperCase()
    const cf = this.codeTarget.value
    if (cf.length < 11) return

    const yearPart = digits(cf.substring(6, 8))
    const month = MONTHS[cf.substring(8, 9)]
    const dayPart = digits(cf.substring(9, 11))
    if (!/^\d{2}$/.test(yearPart) || !/^\d{2}$/.test(dayPart) || !month) return

    let day = parseInt(dayPart, 10)
    if (day > 40) day -= 40 // donne: giorno + 40
    if (day < 1 || day > 31) return

    // anno a due cifre: se è nel futuro è il secolo scorso
    const century = parseInt(yearPart, 10) > new Date().getFullYear() % 100 ? "19" : "20"
    this.birthDateTarget.value = `${century}${yearPart}-${month}-${String(day).padStart(2, "0")}`

    this.birthDateTarget.classList.add("border-success")
    setTimeout(() => this.birthDateTarget.classList.remove("border-success"), 1000)
  }
}
