import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "product", "variant"]
  static values = { index: Array }

  connect() {
    this.timeout = null
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  norm(s) {
    return s.toString().normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase()
  }

  filter() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.render(), 150)
  }

  render() {
    const q = this.norm(this.inputTarget.value)
    this.resultsTarget.innerHTML = ""

    if (q.length === 0) {
      this.resultsTarget.hidden = true
      return
    }

    const matches = []
    this.indexValue.forEach(product => {
      if (this.norm(product.name).includes(q)) {
        matches.push({ type: "product", product })
      }
      product.variants.forEach(variant => {
        if (this.norm(variant.name).includes(q)) {
          matches.push({ type: "variant", product, variant })
        }
      })
    })

    if (matches.length === 0) {
      this.resultsTarget.innerHTML = '<div class="search-no-results">Nenhum resultado</div>'
      this.resultsTarget.hidden = false
      return
    }

    const ul = document.createElement("ul")
    matches.slice(0, 8).forEach(match => {
      const li = document.createElement("li")
      const button = document.createElement("button")
      button.type = "button"
      button.className = "search-result-item"
      if (match.type === "variant") {
        button.textContent = `${match.product.name} › ${match.variant.name}`
        button.dataset.product = match.product.slug
        button.dataset.variant = match.variant.id
      } else {
        button.textContent = match.product.name
        button.dataset.product = match.product.slug
      }
      button.addEventListener("click", () => this.select(button))
      li.appendChild(button)
      ul.appendChild(li)
    })

    this.resultsTarget.appendChild(ul)
    this.resultsTarget.hidden = false
  }

  select(button) {
    this.productTarget.value = button.dataset.product
    if (this.hasVariantTarget) {
      this.variantTarget.value = button.dataset.variant || ""
    }
    this.inputTarget.value = button.textContent
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.hidden = true
  }
}
