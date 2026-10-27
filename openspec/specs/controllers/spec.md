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

### Requirement: `index` exports the current query's issues as csv, pdf or xlsx, gated by `export_allowed?`
The system SHALL check `export_allowed?(:export_issues, @query.base_scope)` (app/controllers/application_controller.rb:580) before producing `format.csv` or `format.pdf`, and SHALL deny access (`deny_access`) when that check fails (app/controllers/issues_controller.rb:51). Today that guard's condition (`request.format.csv? || request.format.pdf?`) lists only those two formats; an `xlsx` format added beside them (RED-8: an "Excel" export, one worksheet named "Issues", columns ID/Subject/Tracker/Status/Priority/Assignee/Updated, bold headers, ID cells hyperlinked to `issue_url(issue)`) must extend this same condition and reuse the same `export_allowed?` call, not a new permission. Each export format builds its row set the same way: `@query.issues(:limit => Setting.issues_export_limit.to_i)` (issues_controller.rb:82 for csv, :87 for pdf) — applying the query's current filters and sort, including issues beyond the current page, up to `Setting.issues_export_limit`; an xlsx format reuses this same call. Each format's filename is built from `filename_for_export(@query, 'issues')` (app/helpers/queries_helper.rb:343) plus the format's extension (`.csv`, `.pdf`), sent as an attachment via `send_data`/`send_file_headers!`, not displayed inline; an xlsx format appends `.xlsx` to the same `filename_for_export` call.

#### Scenario: User without export permission requests csv or pdf
- **WHEN** `index` is requested with `format.csv` or `format.pdf` and `export_allowed?(:export_issues, @query.base_scope)` is false for the current user
- **THEN** the controller calls `deny_access` and returns before building `@issues` or rendering any export body (issues_controller.rb:50-53); an xlsx format must be denied the same way for the same user

#### Scenario: Exported rows follow the query's filters, sort and row limit
- **WHEN** an export format builds its row set
- **THEN** it calls `@query.issues(:limit => Setting.issues_export_limit.to_i)`, which applies the same filters and sort the HTML list uses and returns only issues visible to the current user, capped at `Setting.issues_export_limit`, independent of the HTML list's current page; an xlsx export's rows (including an empty result, which still produces a header-only workbook) come from the same call

## Code map
- app/controllers/issues_controller.rb: `IssuesController`; `before_action :find_issue, :only => [:show, :edit, :update, :issue_tab]` and `before_action :authorize, :except => [:index, :new, :create]` at lines 22-24; `show` action at line 102; `index` action at line 46, export guard at line 51, `format.csv`/`format.pdf` blocks at lines 81-89.
- app/controllers/application_controller.rb: `find_issue` (line 418, loads `@issue`, raises `Unauthorized` unless `@issue.visible?`); `authorize` (line 346, checks the `:view_issues`-style permission map, renders 403/`deny_access`); `find_model_object` (line 406, generic resource loader, not used by `show`/`find_issue`).
- config/routes.rb: `resources :issues do member ... end` block at line 238; existing member routes `edit` (patch) and `tab/:name` (as `tab`); `/issues/preview` is a separate, unrelated route (`previews#issue`, line 41) and must not be reused.
- Entry points: `IssuesController#show` (app/controllers/issues_controller.rb:102), `ApplicationController#find_issue` (app/controllers/application_controller.rb:418), `ApplicationController#authorize` (app/controllers/application_controller.rb:346).
- Depends on this area: none outside the area found by the graph (`affected IssuesController` and `affected ApplicationController` return only other controllers inheriting from `ApplicationController`; no edge to `app/models` or `app/views` because the graph does not resolve Ruby's dynamic `@issue.method` calls or ERB rendering).

Source: commit 53abb0a6c4107c996ee4d478e1f50441f6328912
Graph queries: god-nodes areas/controllers: ApplicationController (126 edges, generic base), IssuesController (23 edges) — both in Code map; affected IssuesController --depth 2: no affected nodes (no edges in, as expected for a leaf controller); affected ApplicationController --depth 2: 36 dependents, all other `*Controller` classes inheriting it (outside this area's scope, e.g. app/controllers/account_controller.rb:20) — confirms `ApplicationController` is a generic hub, not an issues-specific dependency; affected find_issue --depth 2: ambiguous/no unique node match (method name not resolved standalone in the graph) — confirmed by reading application_controller.rb:418 instead; affected ".filename_for_export()" --depth 2: no affected nodes found (the helper is called from issues_controller.rb, but the graph does not resolve `include QueriesHelper` method calls as edges into it) — confirmed by reading issues_controller.rb:83/88 and queries_helper.rb:343 instead.
