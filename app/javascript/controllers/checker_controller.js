import { Controller } from "@hotwired/stimulus"
import { prepare, search } from "lib/checker_search"

const RECENT_KEY = "tajusto:recent"
const RECENT_MAX = 8

// The checker: type a name, tap a stall tile, or tap a recent item → the
// item's card (CEASA price + fair ceiling) opens right under the search box.
export default class extends Controller {
  static targets = ["input", "results", "card", "recent", "recentList", "grid"]
  static values = { index: Array }

  connect() {
    this.prepared = prepare(this.indexValue)
    this.renderRecent()
    const open = this.cardTargets.find(c => !c.hidden)
    if (open) this.remember(open.dataset.item)
    this.element.dataset.ready = "" // e2e hook: search is live
  }

  disconnect() { clearTimeout(this.timer) }

  search() {
    const q = this.inputTarget.value
    this.results = search(this.prepared, q, 6)
    this.renderResults(q, this.results)
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.track("checker_search", {
      q: q.trim().slice(0, 40), results: this.results.length,
      top: this.results[0]?.item.id, loose: !!this.results[0]?.loose
    }), 1200)
  }

  // Keep the box at the top so results sit above the on-screen keyboard.
  lift() { this.inputTarget.scrollIntoView({ block: "start", behavior: "smooth" }) }

  pickFirst(event) {
    event.preventDefault()
    const first = this.results?.[0]
    if (first) this.open(first.item.id, { variety: first.variety, closest: first.closest, source: "search", rank: 0 })
  }

  pick(event) {
    event.preventDefault()
    const el = event.currentTarget
    this.open(el.dataset.item, { source: el.dataset.source || (el.closest(".item-card") ? "confuse" : "tile") })
  }

  close(event) {
    event.preventDefault()
    this.cardTargets.forEach(c => { c.hidden = true })
    history.replaceState(null, "", location.pathname)
  }

  open(id, { variety = null, closest = false, source, rank } = {}) {
    const card = this.cardTargets.find(c => c.dataset.item === id)
    if (!card) return
    this.cardTargets.forEach(c => { c.hidden = c !== card })
    card.querySelector("[data-closest-note]")?.toggleAttribute("hidden", !closest)
    if (variety != null) {
      const row = card.querySelector(`details.variety[data-variety="${variety}"]`)
      if (row) { row.open = true; row.closest(".item-breakdown").open = true }
    }
    this.resultsTarget.hidden = true
    this.inputTarget.blur() // drop the keyboard so the answer is visible
    this.element.querySelector(".checker-search").scrollIntoView({ block: "start" })
    history.replaceState(null, "", `?item=${encodeURIComponent(id)}`)
    this.remember(id)
    const q = source === "search" ? this.inputTarget.value.trim().slice(0, 40) : undefined
    this.track("checker_item_picked", { item: id, source, q, rank, variety, closest })
  }

  renderResults(q, results) {
    const list = this.resultsTarget
    list.replaceChildren()
    if (!q.trim()) { list.hidden = true; return }
    if (!results.length) {
      list.append(this.note("Não achamos esse nome. Tente outro, ou escolha pela banca abaixo."))
    } else if (results[0].loose) {
      list.append(this.note("Resultados aproximados:"))
    }
    results.forEach((r, rank) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "result"
      const icon = this.gridTarget.querySelector(`.tile[data-item="${r.item.id}"] svg`)
      if (icon) button.append(icon.cloneNode(true))
      const text = document.createElement("span")
      text.className = "result-text"
      const name = document.createElement("strong")
      name.textContent = r.item.name + (r.variety != null ? ` › ${r.item.varieties[r.variety]}` : "")
      const price = document.createElement("small")
      price.textContent = (r.closest ? "referência mais próxima · " : "") + (r.item.price || "")
      text.append(name, price)
      button.append(text)
      button.addEventListener("click", () => this.open(r.item.id, { variety: r.variety, closest: r.closest, source: "search", rank }))
      const li = document.createElement("li")
      li.append(button)
      list.append(li)
    })
    list.hidden = false
  }

  note(text) {
    const li = document.createElement("li")
    li.className = "result-note"
    li.textContent = text
    return li
  }

  remember(id) {
    const ids = [id, ...this.recentIds().filter(x => x !== id)].slice(0, RECENT_MAX)
    try { localStorage.setItem(RECENT_KEY, JSON.stringify(ids)) } catch {}
    this.renderRecent()
  }

  recentIds() {
    try { return JSON.parse(localStorage.getItem(RECENT_KEY)) || [] } catch { return [] }
  }

  renderRecent() {
    const tiles = this.recentIds()
      .map(id => this.gridTarget.querySelector(`.tile[data-item="${id}"]`))
      .filter(Boolean)
      .map(tile => { const t = tile.cloneNode(true); t.dataset.source = "recent"; return t })
    this.recentListTarget.replaceChildren(...tiles)
    this.recentTarget.hidden = tiles.length === 0
  }

  track(name, props) { window.posthog?.capture?.(name, props) }
}
