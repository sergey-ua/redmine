# controllers Specification

## Purpose
`app/controllers` handles HTTP requests: it finds and authorizes the requested resource, loads the data a view needs, and renders a response (HTML, API, or a partial for AJAX). `IssuesController` is the controller for the issue area; it inherits the authentication, authorization and error-rendering machinery from `ApplicationController`.

## Requirements

### Requirement: Loading and authorizing an issue before `show`
The system SHALL run `find_issue` as a `before_action` for the `show` action (and `edit`, `update`, `issue_tab`), then run `authorize`.

`find_issue` (`app/controllers/application_controller.rb:418`) loads `@issue = Issue.find(params[:id])` and raises `Unauthorized` unless `@issue.visible?`; a `RecordNotFound` renders a 404. `authorize` (`app/controllers/application_controller.rb:346`) checks `User.current.allowed_to?({:controller => ctrl, :action => action}, @project, ...)` against the `:view_issues` permission map and renders 403 (`deny_access`) when not allowed, or a project-specific 403 when the project is archived or the module is disabled.

#### Scenario: Issue not visible to the current user
- **WHEN** a user requests `show` (or any action sharing the `find_issue`/`authorize` before_action chain) for an issue they cannot see (private issue, no `view_issues` permission, non-member of the project, or an issue that does not exist)
- **THEN** the controller denies access the same way `show` does today: `Unauthorized`/`deny_access` (403) when the issue exists but is not visible, or `render_404` when the record does not exist — before any view-specific data is loaded.

### Requirement: `show` builds the full issue page from `@issue`
The system SHALL build `@issue`'s header, summary fields and description for the full page view after the before_action chain succeeds.

`show` (`app/controllers/issues_controller.rb:102`) uses `@issue.visible_journals_with_index`, `@issue.relations`, `@issue.new_statuses_allowed_to`, and renders `app/views/issues/show.html.erb`, which reads summary fields directly off `@issue` (status, priority, assigned_to, category, fixed_version, dates, done_ratio, estimated_hours) guarded by `@issue.disabled_core_fields.include?(...)` and the description via `textilizable @issue, :description, ...` guarded by `@issue.description?`.

#### Scenario: A field disabled for the issue's tracker is not shown
- **WHEN** the issue's tracker disables a core field (e.g. `priority_id` is in `@issue.disabled_core_fields`)
- **THEN** `show.html.erb` skips that field's row entirely; it is not rendered with a blank or placeholder value.

### Requirement: `index`'s CSV and PDF export formats are gated by `export_allowed?` and share one data fetch
The system SHALL guard `format.csv`, `format.pdf` and `format.xlsx` in `IssuesController#index` (app/controllers/issues_controller.rb:45-90) with a single check at line 51: `if (request.format.csv? || request.format.pdf? || request.format.xlsx?) && !export_allowed?(:export_issues, @query.base_scope); deny_access; return; end`. Each export format then independently loads `@query.issues(:limit => Setting.issues_export_limit.to_i)` (lines 82, 87, and the new xlsx branch) — the same call, repeated per format, not a shared `@issues` set computed once for every export format. `format.csv` (lines 81-85) sends the result through `send_data(query_to_csv(issues, @query, params[:csv]), :type => 'text/csv; header=present', :filename => "#{filename_for_export(@query, 'issues')}.csv")`. `format.pdf` (lines 86-89) assigns `@issues` and calls `send_file_headers! :type => 'application/pdf', :filename => "#{filename_for_export(@query, 'issues')}.pdf"`; the actual PDF bytes are produced by rendering `app/views/issues/index.pdf.erb`, which calls `issues_to_pdf(@issues, @project, @query)` (`Redmine::Export::PDF::IssuesPdfHelper#issues_to_pdf`, lib/redmine/export/pdf/issues_pdf_helper.rb:254, mixed into `IssuesHelper`). `format.xlsx` is the third, parallel export branch, covered by its own requirement below.

When `@query` is invalid, the invalid-query branch's `format.any(:atom, :csv, :pdf)` (around line 91) also covers `:xlsx`, so an invalid query returns 422 (`head :unprocessable_content`) for an xlsx request exactly as it already does for csv/pdf, instead of falling through to a 200 with an unguarded or malformed workbook.

`export_allowed?(permission, scope)` (app/controllers/application_controller.rb:580-598, private, exposed via `helper_method`) is: true for `user.admin?`; otherwise, if `@project` is set, false unless `user.allowed_to?(permission, @project)`, and true if `@project.leaf?` (no subprojects); if `@project` is not set (cross-project/global `/issues`), false unless `user.allowed_to?(permission, nil, :global => true)`; in both remaining cases, false if `scope` contains any record whose `project_id` is not in `Project.allowed_to(user, permission)` — this final check is what denies a cross-project or subproject export when the user lacks the permission on at least one project the results would span.

#### Scenario: Export format requested without the export permission
- **WHEN** a non-admin user without the `:export_issues` permission (for the given project or globally) requests `format => 'csv'`, `format => 'pdf'`, or `format => 'xlsx'` on `index`
- **THEN** the controller calls `deny_access` and returns before building `respond_to`'s export branch — a 403, not an empty or partial export file

#### Scenario: Export spans a subproject the user lacks the permission on
- **WHEN** the request has permission on `@project` itself (or is a global, cross-project request with the permission granted globally) but `@query.base_scope` includes issues from a subproject (or another project in a global query) where the user lacks `:export_issues`
- **THEN** the final `scope.where.not(...).exists?` check in `export_allowed?` still denies the export, even though the earlier per-project checks passed, regardless of which of csv, pdf or xlsx was requested

#### Scenario: Invalid query requested as xlsx
- **WHEN** `@query.valid?` is false and the request's format is `xlsx`
- **THEN** the controller responds with `head :unprocessable_content` (422), the same as it does today for an invalid csv or pdf request, and builds no workbook

### Requirement: The "other formats" export links are shown only when `export_allowed?` passes
The system SHALL compute `export_allowed = export_allowed?(:export_issues, @query.base_scope)` once in `app/views/issues/index.html.erb:37` and only emit the CSV and PDF entries inside the `other_formats_links` block (app/helpers/application_helper.rb:852-856, built via `Redmine::Views::OtherFormatsBuilder#link_to_with_query_parameters`, lib/redmine/views/other_formats_builder.rb:35) when `export_allowed` is true; the Atom link is emitted unconditionally, independent of `export_allowed`.

#### Scenario: User without export permission views the issue list
- **WHEN** `export_allowed?` is false for the current user/project/scope
- **THEN** `index.html.erb` renders no `a.csv` or `a.pdf` link in the `p.other-formats` block (and no `#csv-export-options` block), but still renders the Atom link; a direct `?format=csv` or `?format=pdf` request still gets denied by the controller guard above, independent of what the view rendered

### Requirement: `index`'s xlsx export format builds a single-worksheet workbook from the export data fetch
The system SHALL, when `format.xlsx` is requested on `IssuesController#index` and the guard above passes, fetch `issues = @query.issues(:limit => Setting.issues_export_limit.to_i)` (the same call pattern as `format.csv`/`format.pdf`, independently fetched, not a shared `@issues`) and build one workbook with exactly one worksheet named `"Issues"`.

The worksheet SHALL have a header row with exactly these 7 columns, in this order: ID, Subject, Tracker, Status, Priority, Assignee, Updated. The header row's cells SHALL be rendered bold.

For each issue in `issues`, in the order returned by the query (current filters and sort, as `@query.issues` already applies), the system SHALL write one data row with:
- ID: the issue's id, rendered as a hyperlink to `issue_url(issue)` (the full URL, not a relative path).
- Subject: the issue's subject, written with an explicit string/text cell type so that a value beginning with `=`, `+`, `-`, or `@` is never evaluated as a spreadsheet formula.
- Tracker: the issue's tracker name.
- Status: the issue's status name.
- Priority: the issue's priority name.
- Assignee: the assigned user's name, or blank (empty cell) when `issue.assigned_to` is `nil`.
- Updated: the issue's `updated_on` timestamp, formatted through the same user-timezone-aware time formatting used elsewhere in the app (`format_time`).

When `issues` is empty, the system SHALL still send a valid workbook containing the "Issues" worksheet with only the header row (no data rows) — not an error and not an empty/zero-byte response.

The system SHALL send the generated workbook as a file download (not rendered inline) via `send_data`, with filename `"#{filename_for_export(@query, 'issues')}.xlsx"` and an xlsx-appropriate content type, mirroring how `format.csv` sends its result.

This requirement does not change `format.csv` or `format.pdf`, which continue to produce identical output to before this change.

#### Scenario: Workbook structure and header
- **WHEN** a user with export permission requests `index` with `format => 'xlsx'`
- **THEN** the response is a valid xlsx workbook containing exactly one worksheet named "Issues", whose first row has exactly 7 cells reading ID, Subject, Tracker, Status, Priority, Assignee, Updated in that order, rendered bold, and the response is sent as a download named `"#{filename_for_export(@query, 'issues')}.xlsx"`

#### Scenario: ID cell is a clickable hyperlink
- **WHEN** the worksheet is built for an issue
- **THEN** that issue's ID cell is a hyperlink whose target is `issue_url(issue)` (the full URL), not plain text and not a relative path

#### Scenario: Subject is never read as a formula
- **WHEN** an issue's subject starts with `=`, `+`, `-`, or `@` (for example, `=SUM(A1:A2)`)
- **THEN** the Subject cell contains that literal text and is not evaluated as a formula when the workbook is opened

#### Scenario: Unassigned issue leaves Assignee blank
- **WHEN** an issue in the exported result has `assigned_to` set to `nil`
- **THEN** that issue's Assignee cell is blank, not a placeholder string

#### Scenario: Updated column reflects the viewing user's timezone
- **WHEN** the workbook is built for a user with a configured timezone different from the server's
- **THEN** each issue's Updated cell shows `updated_on` formatted in that user's timezone, the same way the rest of the application displays timestamps for that user

#### Scenario: Empty result still produces a valid workbook
- **WHEN** `@query.issues(:limit => Setting.issues_export_limit.to_i)` returns no issues (e.g. filters match nothing)
- **THEN** the response is still a valid xlsx workbook with the "Issues" worksheet containing only the bold header row, sent as a download — not an error response and not an empty body

## Code map
- app/controllers/issues_controller.rb: `IssuesController`; `before_action :find_issue, :only => [:show, :edit, :update, :issue_tab]` and `before_action :authorize, :except => [:index, :new, :create]` at lines 22-24; `show` action at line 102; `index` action at line 45, export guard at line 51, `format.csv`/`format.pdf` branches at lines 81-89.
- app/controllers/application_controller.rb: `find_issue` (line 418, loads `@issue`, raises `Unauthorized` unless `@issue.visible?`); `authorize` (line 346, checks the `:view_issues`-style permission map, renders 403/`deny_access`); `find_model_object` (line 406, generic resource loader, not used by `show`/`find_issue`); `export_allowed?` (line 580, private + `helper_method`, permission/scope gate for exports).
- app/helpers/application_helper.rb: `other_formats_links` (line 852) wraps `Redmine::Views::OtherFormatsBuilder` to build the export-link row.
- lib/redmine/views/other_formats_builder.rb: `link_to_with_query_parameters` (line 35), preserves current query params when building a format link.
- lib/redmine/export/pdf/issues_pdf_helper.rb: `issues_to_pdf` (line 254), builds the PDF document rendered by `app/views/issues/index.pdf.erb` for `format.pdf`.
- config/routes.rb: `resources :issues do member ... end` block at line 238; existing member routes `edit` (patch) and `tab/:name` (as `tab`); `/issues/preview` is a separate, unrelated route (`previews#issue`, line 41) and must not be reused.
- Entry points: `IssuesController#show` (app/controllers/issues_controller.rb:102), `IssuesController#index` (app/controllers/issues_controller.rb:45), `ApplicationController#find_issue` (app/controllers/application_controller.rb:418), `ApplicationController#authorize` (app/controllers/application_controller.rb:346), `ApplicationController#export_allowed?` (app/controllers/application_controller.rb:580).
- Depends on this area: none outside the area found by the graph (`affected IssuesController` and `affected ApplicationController` return only other controllers inheriting from `ApplicationController`; no edge to `app/models` or `app/views` because the graph does not resolve Ruby's dynamic `@issue.method` calls or ERB rendering). `affected export_allowed?` (depth 2) shows its callers: `TimelogController#report`/`#index`, `GanttsController#show`, `IssuesController#index`/`#retrieve_previous_and_next_issue_ids`, `ReportsController#issue_report_details` — any change to `export_allowed?`'s signature or semantics is felt by all of these, not just `IssuesController`.

Source: commit 53abb0a6c4107c996ee4d478e1f50441f6328912
Graph queries: god-nodes areas/controllers: ApplicationController (126 edges, generic base), IssuesController (23 edges) — both in Code map; affected IssuesController --depth 2: no affected nodes (no edges in, as expected for a leaf controller); affected ApplicationController --depth 2: 36 dependents, all other `*Controller` classes inheriting it (outside this area's scope, e.g. app/controllers/account_controller.rb:20) — confirms `ApplicationController` is a generic hub, not an issues-specific dependency; affected find_issue --depth 2: ambiguous/no unique node match (method name not resolved standalone in the graph) — confirmed by reading application_controller.rb:418 instead; affected "export_allowed?" --depth 2 --graph /workspace/knowledge/graph/redmine/graph.json: 6 dependents — `.report()` timelog_controller.rb:82, `.show()` gantts_controller.rb:40, `.index()` issues_controller.rb:51, `.issue_report_details()` reports_controller.rb:47, `.index()` timelog_controller.rb:46, `.retrieve_previous_and_next_issue_ids()` issues_controller.rb:552 — in Code map's "Depends on this area"; affected "IssuesController" --depth 2: no affected nodes found; path "IssuesController" "filename_for_export" (directed): no path found (cross-area call not resolved by the graph; confirmed by reading issues_controller.rb:84/88 instead, which call it directly).
