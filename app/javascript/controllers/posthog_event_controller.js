import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { name: String, properties: Object }

  connect() {
    if (window.posthog) window.posthog.capture(this.nameValue, this.propertiesValue)
  }
}
