import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggleMenu(event) {
    event.preventDefault()
    event.stopPropagation()

    const isOpen = this.menuTarget.classList.contains("open")
    if (isOpen) {
      this.#close()
    } else {
      this.#open()
    }
  }

  closeMenu() {
    this.#close()
  }

  closeOnBackdrop(event) {
    // Only close if clicking on the backdrop itself, not the menu panel
    if (event.target === this.menuTarget) {
      this.#close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && this.menuTarget.classList.contains("open")) {
      this.#close()
    }
  }

  // Private

  #open() {
    this.menuTarget.classList.add("open")
    this.element.querySelector(".header-hamburger")?.classList.add("open")
  }

  #close() {
    this.menuTarget.classList.remove("open")
    this.element.querySelector(".header-hamburger")?.classList.remove("open")
  }
}
