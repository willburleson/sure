import { Controller } from "@hotwired/stimulus";

// Drag-to-reorder list of account groups on the Appearance settings page.
// Pointer events cover mouse, pen and touch; arrow keys on the handle cover
// keyboard users. Each item carries a hidden input, so moving the item in the
// DOM changes the order the enclosing form posts. The form is submitted after
// every change.
export default class extends Controller {
  static targets = ["item"];

  grab(event) {
    if (event.button !== 0) return;
    event.preventDefault();

    this.dragged = event.currentTarget.closest("[data-account-group-order-target='item']");
    this.startOrder = this.currentOrder();
    this.dragged.classList.add("opacity-50", "shadow-lg");

    this.onMove = this.move.bind(this);
    this.onRelease = this.release.bind(this);
    window.addEventListener("pointermove", this.onMove);
    window.addEventListener("pointerup", this.onRelease);
    window.addEventListener("pointercancel", this.onRelease);
  }

  move(event) {
    if (!this.dragged) return;

    const target = this.itemTargets.find((item) => {
      if (item === this.dragged) return false;
      const rect = item.getBoundingClientRect();
      return event.clientY >= rect.top && event.clientY <= rect.bottom;
    });
    if (!target) return;

    const rect = target.getBoundingClientRect();
    const before = event.clientY < rect.top + rect.height / 2;
    target.parentNode.insertBefore(this.dragged, before ? target : target.nextSibling);
  }

  release() {
    window.removeEventListener("pointermove", this.onMove);
    window.removeEventListener("pointerup", this.onRelease);
    window.removeEventListener("pointercancel", this.onRelease);
    if (!this.dragged) return;

    this.dragged.classList.remove("opacity-50", "shadow-lg");
    this.dragged = null;
    if (this.currentOrder() !== this.startOrder) this.save();
  }

  keydown(event) {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return;
    event.preventDefault();

    const item = event.currentTarget.closest("[data-account-group-order-target='item']");
    if (event.key === "ArrowUp" && item.previousElementSibling) {
      item.parentNode.insertBefore(item, item.previousElementSibling);
    } else if (event.key === "ArrowDown" && item.nextElementSibling) {
      item.parentNode.insertBefore(item.nextElementSibling, item);
    } else {
      return;
    }
    event.currentTarget.focus();
    this.save();
  }

  currentOrder() {
    return this.itemTargets.map((item) => item.querySelector("input").value).join(",");
  }

  save() {
    this.element.closest("form")?.requestSubmit();
  }
}
