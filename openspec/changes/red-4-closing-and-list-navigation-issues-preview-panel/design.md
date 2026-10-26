# Design

## Context

`app/assets/javascripts/issues_quick_preview.js` today defines only `closePanel()` and binds it to `#quick-preview-panel [data-quick-preview-close]`. The list's query form (`#query_form`, `app/views/issues/index.html.erb`), sort-header links (`sort_link`/`sort_header_tag`, `app/helpers/sort_helper.rb`), and pagination links (`pagination_links_full`, `lib/redmine/pagination.rb`) are all plain, non-AJAX GET navigations with no existing hook into the panel's JS. See proposal.md - Why.

## Goals / Non-Goals

**Goals:**
- Close the panel synchronously, client-side, before any of the three navigation triggers takes effect.
- Never block, delay, or alter the resulting navigation (no `preventDefault()`).

**Non-Goals:**
- Making the query form, sort links, or pagination links AJAX — out of scope; they stay plain GET navigations.
- Changing the server-side `quick_preview` endpoint — owned by the sibling `red-4-closing-and-list-navigation-controllers` change.
- Per-page selector or group-by links rendered outside `table.list thead` / `.pagination` — not covered by the ticket's literal scope (query form, sort header, pagination link only).

## Decisions

- **Selector scope**: `table.list thead th a` for sort headers, `.pagination a` for pagination. Confirmed by reading `column_header` (`app/helpers/queries_helper.rb:203-236`): non-sortable columns render plain text, not `<a>`, so no false positives; the sort-state class (`sort asc/desc`) only applies to the current column, so matching must not depend on it. `.pagination a` only wraps `pagination_links_full`/`pagination_links_each` output (`index.html.erb:34`). Row action links, "Preview", and context-menu links sit outside both containers and are unaffected. Alternative considered: a dedicated CSS marker class on each link — rejected as an unnecessary view-layer change when the existing structural selectors are unambiguous.
- **Event delegation, not `preventDefault`**: both handlers run `closePanel()` only, with no call to `preventDefault()` or `stopPropagation()`, so the browser's default navigation proceeds in the same tick. This satisfies "SHALL NOT be blocked, cancelled, or delayed" directly — closePanel() only toggles `classList`/`aria-hidden`, which costs no observable time before unload.
- **Shared open-check**: extract the `body.quick-preview-open` check already implicit in `closePanel()`'s callers into a small `isPanelOpen()` helper, reused by the existing close-button handler and both new handlers, so the two new handlers short-circuit when the panel is already closed (matches the "already closed" scenario).
- **Delegated binding on `document`**: both new handlers bind via `$(document).on(...)`, consistent with the existing close-button handler's delegation pattern, so they work regardless of whether the list is re-rendered via partial AJAX elsewhere.

## Risks / Trade-offs

- [Selector drift if `table.list` or `.pagination` markup changes elsewhere] → Both selectors are already used as the stable structural hooks for this view; no other change in this ticket touches that markup.
- [A future AJAX-ified sort/pagination link would double-fire a close plus a stale page state] → Out of scope for this change; would need revisiting if `sort_link`/`pagination_links_full` ever gain `:remote => true` (owned by a different capability if it happens).
