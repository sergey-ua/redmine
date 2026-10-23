/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */

import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

export default class extends Controller {
  static targets = ["panel", "content"]

  // Fetches the issue preview fragment and swaps it into the panel without
  // navigating or re-rendering the issue list.
  async open(event) {
    event.preventDefault()

    const url = event.currentTarget.getAttribute("href")
    if (!url) return

    let response
    try {
      response = await get(url, { responseKind: "html" })
    } catch {
      return
    }
    if (!response.ok) return

    this.contentTarget.innerHTML = await response.html
    this.panelTarget.classList.remove("hidden")
    document.body.classList.add("issue-preview-open")
  }

  close(event) {
    event.preventDefault()
    this.panelTarget.classList.add("hidden")
    this.contentTarget.innerHTML = ""
    document.body.classList.remove("issue-preview-open")
  }
}
