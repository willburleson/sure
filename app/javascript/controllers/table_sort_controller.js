import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="table-sort"
//
// Client-side sort for a small table. Each sortable <th> holds a button with
// data-action="table-sort#sort" and data-table-sort-key-param="<key>"; each
// body <tr> carries data-sort-<key> values. Values sort numerically when both
// parse as numbers, otherwise as strings; blanks always sort last. Clicking
// the active column flips the direction.
export default class extends Controller {
  static targets = ["body", "header"];

  sort(event) {
    const key = event.params.key;
    const header = event.currentTarget.closest("th");
    const current = header.getAttribute("aria-sort");
    const direction =
      current === "ascending"
        ? "descending"
        : current === "descending"
          ? "ascending"
          : event.params.default || "ascending";

    for (const th of this.headerTargets) th.removeAttribute("aria-sort");
    header.setAttribute("aria-sort", direction);

    const sign = direction === "ascending" ? 1 : -1;
    const rows = Array.from(this.bodyTarget.rows);
    rows.sort((a, b) => {
      const x = a.dataset[this.#datasetKey(key)] ?? "";
      const y = b.dataset[this.#datasetKey(key)] ?? "";
      if (x === "" || y === "") return (x === "") - (y === "");
      const nx = Number(x);
      const ny = Number(y);
      const cmp =
        Number.isNaN(nx) || Number.isNaN(ny)
          ? x.localeCompare(y)
          : nx - ny;
      return cmp * sign;
    });
    this.bodyTarget.append(...rows);
  }

  #datasetKey(key) {
    return `sort${key.charAt(0).toUpperCase()}${key.slice(1)}`;
  }
}
