import { Controller } from "@hotwired/stimulus";

// Formats an account's "last refreshed" time in the viewer's timezone:
// "9:06 AM" today, "11/17" earlier this year, "6/18/2025" before that.
// Older than staleDays turns red. Runs client-side because the sidebar is a
// fragment cached for hours, so server-rendered "today" would go wrong.
//
// Connects to data-controller="refreshed-at"
export default class extends Controller {
  static values = { time: String, staleDays: { type: Number, default: 3 } };

  connect() {
    const at = new Date(this.timeValue);
    if (Number.isNaN(at.getTime())) return;

    const now = new Date();
    let text;
    if (at.toDateString() === now.toDateString()) {
      text = at.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
    } else if (at.getFullYear() === now.getFullYear()) {
      text = at.toLocaleDateString([], { month: "numeric", day: "numeric" });
    } else {
      text = at.toLocaleDateString([], {
        month: "numeric",
        day: "numeric",
        year: "numeric",
      });
    }

    this.element.textContent = text;
    this.element.title = at.toLocaleString();

    const stale = now - at > this.staleDaysValue * 24 * 60 * 60 * 1000;
    this.element.classList.toggle("text-destructive", stale);
    this.element.classList.toggle("text-secondary", !stale);
  }
}
