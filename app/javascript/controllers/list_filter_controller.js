import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "clearBtn", "count"]
  static values = { url: String, debounce: { type: Number, default: 700 } }

  connect() {
    this.timeout = null
    this.updateClearVisibility()
  }

  submit() {
    const params = new URLSearchParams()
    this.element.querySelectorAll("select, input").forEach(el => {
      if (el.name && el.value) {
        if (el.type === "checkbox") {
          if (el.checked) params.set(el.name, el.value)
        } else {
          params.set(el.name, el.value)
        }
      }
    })

    const url = this.urlValue || window.location.pathname
    Turbo.visit(`${url}?${params.toString()}`, { action: "replace" })
  }

  debouncedSubmit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.submit(), this.debounceValue)
  }

  clear() {
    this.element.querySelectorAll("select").forEach(s => { s.value = "" })
    this.element.querySelectorAll("input[type=text]").forEach(i => { i.value = "" })
    this.element.querySelectorAll("input[type=checkbox]").forEach(c => { c.checked = false })
    this.submit()
  }

  updateClearVisibility() {
    if (!this.hasClearBtnTarget) return
    const hasActive = Array.from(this.element.querySelectorAll("select, input")).some(el => {
      if (el.type === "checkbox") return el.checked
      if (el.name === "sort") return false
      return el.value !== ""
    })
    this.clearBtnTarget.style.display = hasActive ? "" : "none"
  }
}
