# Proposal

## Why

RED-1 added the preview panel's close button (`closePanel()`), but nothing today closes the panel before the list navigates away via the query form, a sort header, or a pagination link. The main spec for `issues-preview-panel` already documents the intended "closes first" behaviour; this proposal implements it so the panel never stays visibly open (stale `body.quick-preview-open` / panel state) across a page navigation.

## What Changes

- Add a delegated `submit` handler on `#query_form` in `app/assets/javascripts/issues_quick_preview.js` that closes the panel (if open) and lets the form submit proceed unmodified.
- Add a delegated `click` handler on sort-header links (`table.list thead th a`) and pagination links (`.pagination a`) that closes the panel (if open) and lets the navigation proceed unmodified.
- No `preventDefault()` in either handler — the navigation is not blocked, cancelled, or delayed.
- No changes to Ruby controllers, ERB views, or CSS. No changes to the `quick_preview` endpoint, which is owned by the sibling change `red-4-closing-and-list-navigation-controllers` and is only consumed here as the panel's existing AJAX call.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `issues-preview-panel`: the "Navigation away from the list closes the panel first" requirement is implemented (header and scenarios already present in the main spec from an earlier docs step; this delta attaches the design/tasks that make it true in code).

## Impact

- `app/assets/javascripts/issues_quick_preview.js`: two new delegated jQuery handlers; `closePanel()`'s open-check extracted into a small shared helper.
- `test/system/issues_quick_preview_test.rb`: new system tests for filter-submit, sort-header, and pagination-link closing an open panel, plus a negative case (panel already closed).
- No changes to `app/controllers/issues_controller.rb`, `app/views/issues/*.erb`, `app/helpers/sort_helper.rb`, `lib/redmine/pagination.rb`, or `app/assets/stylesheets/issues_quick_preview.css` — those files are read-only context (sort/pagination links stay plain, non-AJAX `<a>` elements) or belong to the sibling `controllers` domain.

## Traceability

- Ticket: RED-4
- Domain: issues-preview-panel
- Criteria: Close button leaves filters, sort, page and scroll position unchanged, no list reload; Applying a filter, sort or page while a preview is open closes the panel first, then navigation proceeds as before the feature; Opening, switching and closing previews never trigger a full list page reload.
