# issues-preview-panel Specification

## Purpose
Lets users inspect an issue's key fields and description from an issue list, via an AJAX side panel, without navigating away from the list.

## Requirements

### Requirement: Preview trigger on every issue-list row
Every row of the global `/issues` list and every project-scoped issue list SHALL display a "Preview" action that is visually and functionally distinct from the existing issue ID/subject link.

#### Scenario: Preview trigger present on global issue list
- **WHEN** a user views the global `/issues` list
- **THEN** each issue row shows a "Preview" action separate from the ID/subject link

#### Scenario: Preview trigger present on a project issue list
- **WHEN** a user views a project's issue list
- **THEN** each issue row shows a "Preview" action separate from the ID/subject link

### Requirement: AJAX panel open, switch and close without full page reload
Opening the preview panel, switching it to a different issue, and closing it SHALL never trigger a full page navigation or reload. Opening and switching SHALL load panel content via an asynchronous (AJAX) request (`.quick-preview-trigger`, `:remote => true`, handled by `quick_preview.js.erb`). Closing SHALL be handled entirely client-side: `closePanel()` (`app/assets/javascripts/issues_quick_preview.js`) removes the `quick-preview-open` class from `body` and the `open` class (and sets `aria-hidden="true"`) on `#quick-preview-panel`, bound to clicks on `#quick-preview-panel [data-quick-preview-close]`. None of these three actions issues a GET navigation or reloads the current page.

#### Scenario: Clicking Preview does not navigate away
- **WHEN** a user clicks "Preview" on an issue row
- **THEN** the browser does not perform a full page navigation
- **AND** the panel is populated with that issue's preview content

#### Scenario: Switching the preview to another issue does not navigate away
- **WHEN** a preview panel is already open and the user clicks "Preview" on a different issue row
- **THEN** the browser does not perform a full page navigation
- **AND** the panel body is replaced with the newly requested issue's preview content

#### Scenario: Closing the preview does not navigate away or reload
- **WHEN** a user clicks the panel's close control (`[data-quick-preview-close]`)
- **THEN** the browser does not perform a full page navigation or reload
- **AND** `closePanel()` runs entirely in the browser with no request to the server

### Requirement: Closing the panel leaves the underlying list state unchanged
Closing the preview panel SHALL only hide the panel. It SHALL NOT alter the underlying issue list's filters, sort order, page, or scroll position, and SHALL NOT make any server request.

#### Scenario: Close button leaves list state untouched
- **WHEN** a user has applied filters, a sort order, and a page/scroll position on the issue list, opens the preview panel, and then clicks the close control
- **THEN** the panel is hidden
- **AND** the list's filters, sort order, current page, and scroll position are all unchanged from before the panel was opened

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

### Requirement: Underlying list remains visible and usable while panel is open
On desktop viewports, the issue list SHALL remain visible and usable (scrollable, clickable) while the preview panel is open.

#### Scenario: List stays interactive with panel open
- **WHEN** the preview panel is open on a desktop viewport
- **THEN** the issue list underneath remains visible
- **AND** the user can still scroll and click other rows in the list

### Requirement: Panel header content
The preview panel SHALL display a header containing the issue ID, the issue subject, an "Open full issue" link to the issue's full page, and a control to close the panel.

#### Scenario: Header shows id, subject, link, and close control
- **WHEN** the preview panel is opened for an issue
- **THEN** the header shows that issue's ID and subject
- **AND** the header includes an "Open full issue" link pointing to the full issue page
- **AND** the header includes a control that closes the panel

### Requirement: Panel summary fields limited to project, tracker, status, priority, assignee
The preview panel's summary section SHALL display exactly these fields: project, tracker, status, priority, and assignee. Priority and assignee SHALL be omitted when disabled via the issue's `disabled_core_fields`, consistent with the full issue page. Category, fixed version, start/due dates, done ratio, estimated hours, and spent time are out of scope for this panel and SHALL NOT be displayed here.

#### Scenario: Summary shows the five fields
- **WHEN** the preview panel is opened for an issue with priority and assignee both enabled
- **THEN** the summary section shows the issue's project, tracker, status, priority, and assignee

#### Scenario: Assignee absent shows Unassigned
- **WHEN** the preview panel is opened for an issue with no assignee
- **THEN** the summary section shows "Unassigned" for the assignee field

#### Scenario: Disabled priority field is omitted
- **WHEN** the preview panel is opened for an issue whose tracker disables the priority core field
- **THEN** the summary section does not display a priority row

#### Scenario: Disabled assignee field is omitted
- **WHEN** the preview panel is opened for an issue whose tracker disables the assigned_to core field
- **THEN** the summary section does not display an assignee row

#### Scenario: Extended fields are not shown
- **WHEN** the preview panel is opened for any issue
- **THEN** the summary section does not display category, fixed version, start date, due date, done ratio, estimated hours, or spent time

### Requirement: Description rendering with placeholder
The preview panel SHALL render the issue's description using the same rendering used on the full issue page. When the issue has no description, the panel SHALL show a "No description" placeholder instead.

#### Scenario: Description present is rendered
- **WHEN** the preview panel is opened for an issue with a non-blank description
- **THEN** the panel shows the rendered description content

#### Scenario: Description blank shows placeholder
- **WHEN** the preview panel is opened for an issue with a blank description
- **THEN** the panel shows a "No description" placeholder

### Requirement: Server-side preview endpoint enforces full issue visibility
The server-side endpoint backing the preview panel SHALL re-check issue visibility and authorization using the same mechanism as the full issue page (`IssuesController#show`'s `find_issue`/`authorize` chain), and SHALL respect `disabled_core_fields` for the summary fields it returns.

#### Scenario: Visible issue returns preview content
- **WHEN** a user who can view a given issue requests its preview
- **THEN** the server returns the preview content for that issue

#### Scenario: Non-visible issue is rejected
- **WHEN** a user who cannot view a given issue (per `Issue#visible?`) requests its preview
- **THEN** the server does not return that issue's preview content and responds the same way `show` would for a non-visible issue

#### Scenario: Nonexistent issue is rejected
- **WHEN** a request is made for a preview of an issue id that does not exist
- **THEN** the server responds the same way `show` would for a nonexistent issue (not found), without rendering a panel

### Requirement: The server-side preview endpoint never alters the list's session state
The server-side `quick_preview` endpoint (and its `find_issue` before_action) SHALL NOT read or write the list's session state (`session[:issue_query]`, the sort session key, or `session[:per_page]`), regardless of whether the client is opening, switching, or closing the panel. That state is written only by the list action (`index`) via `retrieve_query` (`app/helpers/queries_helper.rb:352`).

#### Scenario: List query state unchanged after opening or switching a preview
- **WHEN** a user has a list open with filters, sort, and pagination applied (stored in `session[:issue_query]` and related session keys), and then requests `quick_preview` to open a preview or switch it to a different issue
- **THEN** `session[:issue_query]` and the sort/pagination session state are unchanged after the request
- **AND** a subsequent re-render of the list (`index`) reflects the same filters, sort, and pagination as before

### Requirement: Out-of-scope panel features
The preview panel SHALL NOT include recent comments, a "view full history" link, handling of race conditions between rapid successive Preview clicks, or keyboard/focus management. These remain explicitly out of scope for this capability.

#### Scenario: No recent comments or history link shown
- **WHEN** the preview panel is opened for any issue
- **THEN** the panel does not display recent comments or a "view full history" link

#### Scenario: No defined behavior for rapid clicks or keyboard focus
- **WHEN** a user rapidly clicks Preview on multiple rows, or uses keyboard navigation
- **THEN** this capability defines no required behavior for those situations

## Code map
- app/controllers/issues_controller.rb: `quick_preview` action (line 257, `before_action :find_issue` only, no `authorize`; `respond_to { |format| format.js }`).
- app/views/issues/quick_preview.js.erb: renders the `issues/quick_preview` partial into the panel DOM node and toggles `open`/`aria-hidden`; no redirect, no navigation.
- app/controllers/application_controller.rb: `find_issue` (line 418) — sets `@issue`/`@project` only, no session access.
- app/helpers/queries_helper.rb: `retrieve_query` (line 352) — sole writer of `session[:issue_query]`; invoked only from `index`, never from `quick_preview`.
- lib/redmine/preparation.rb:58 — maps the `quick_preview` action to the `:view_issues` permission.
- app/assets/javascripts/issues_quick_preview.js — `closePanel()` (L2-5); click handler on `#quick-preview-panel [data-quick-preview-close]` (L7-9).
- app/views/issues/_list.html.erb:43 — `.quick-preview-trigger` link (`quick_preview_issue_path`, `:remote => true`).
- app/views/issues/index.html.erb — hosts `#query_form` (L24), `#quick-preview-panel` container, and `pagination_links_full` (L34).
- app/helpers/sort_helper.rb:113-150 — `sort_link`/`sort_header_tag`, plain `link_to`, no `:remote`.
- lib/redmine/pagination.rb:143-199 — `pagination_links_full`/`pagination_links_each`, plain `link_to`, no `:remote`.
- Depends on this area: see `controllers` spec's "`quick_preview` and `find_issue` never alter the list's session state" requirement, which documents the same invariant from the controller side. Also, `app/views/issues/index.html.erb` (query form, pagination, panel container), `app/helpers/sort_helper.rb`, and `lib/redmine/pagination.rb` — Graphify does not classify ERB or confirm these edges (unclassified files); confirmed by reading each file directly.
- No outside caller of `closePanel()` exists yet: the close-before-navigate requirement introduces the first such caller, to be added on `#query_form` submit and on sort/pagination link clicks.

Source: commit dd0c57557a1bedce158a2af8d9d5fcd8453c4735 (controller/session facts); 0b7199619b70d1a04f219a01e0ba21dd2df94972 (origin/master, client-side facts)
Graph queries: affected ".quick_preview()" --depth 2: no affected nodes found (leaf action; nothing calls into or depends on it); path from quick_preview to index: no directed path found (confirms no call chain between the preview endpoint and the list action); affected ApplicationController#find_issue --depth 2: no affected nodes found; `graphify affected "closePanel" --depth 2 --graph /workspace/knowledge/graph/redmine/areas/js/graph.json` → "No affected nodes found." (closePanel has no dependents in the JS graph; only reached via jQuery delegated event binding, not a static call edge); `graphify affected "closePanel" --depth 2` on the whole-repo graph → "No unique node match for closePanel"; `graphify affected "query_form" --depth 2` → "No unique node match for query_form" (ERB ids/selectors are not graph nodes); `graphify path "closePanel" "query_form"` → "No node matching 'closePanel' found" (ERB files unclassified by Graphify — "32 file(s) not classified" per area build report — confirmed instead by reading `app/views/issues/index.html.erb`, `app/helpers/sort_helper.rb`, and `lib/redmine/pagination.rb` directly).
