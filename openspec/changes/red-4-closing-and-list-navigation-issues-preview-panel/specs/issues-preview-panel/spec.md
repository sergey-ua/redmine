# Spec Delta

## MODIFIED Requirements

### Requirement: Navigation away from the list closes the panel first
If the preview panel is open when the user submits the list's query form (`#query_form`, filter/sort), follows a sort-header link, or follows a pagination link, the panel SHALL be closed before the resulting navigation proceeds. The navigation itself (the GET request/page load) SHALL NOT be blocked, cancelled, or delayed beyond the act of closing the panel: closing is a client-side, synchronous DOM update and adds no meaningful delay.

None of `#query_form`'s submit, the sort-header links built by `sort_link`/`sort_header_tag` (`app/helpers/sort_helper.rb`), or the pagination links built by `pagination_links_full` (`lib/redmine/pagination.rb`) are AJAX (`:remote => true`) today; each is a plain full-page GET navigation, and this requirement does not change that — it only ensures the panel is not left visibly open, with stale `body.quick-preview-open`/panel state, across that navigation.

#### Scenario: Submitting the query form while the panel is open closes it first
- **WHEN** the preview panel is open and the user submits `#query_form` (e.g. changes a filter or sort column and applies it)
- **THEN** the panel is closed
- **AND** the form submission proceeds and navigates the browser to the filtered/sorted list unmodified

#### Scenario: Following a sort header while the panel is open closes it first
- **WHEN** the preview panel is open and the user clicks a sort-header link
- **THEN** the panel is closed
- **AND** the browser navigates to the sorted list unmodified

#### Scenario: Following a pagination link while the panel is open closes it first
- **WHEN** the preview panel is open and the user clicks a pagination link (e.g. next page or per-page option)
- **THEN** the panel is closed
- **AND** the browser navigates to the requested page unmodified

#### Scenario: Navigating away when the panel is already closed is unaffected
- **WHEN** the preview panel is not open and the user submits `#query_form`, follows a sort-header link, or follows a pagination link
- **THEN** the navigation proceeds exactly as it would without this capability
