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

## Code map
- app/controllers/issues_controller.rb: `IssuesController`; `before_action :find_issue, :only => [:show, :edit, :update, :issue_tab]` and `before_action :authorize, :except => [:index, :new, :create]` at lines 22-24; `show` action at line 102.
- app/controllers/application_controller.rb: `find_issue` (line 418, loads `@issue`, raises `Unauthorized` unless `@issue.visible?`); `authorize` (line 346, checks the `:view_issues`-style permission map, renders 403/`deny_access`); `find_model_object` (line 406, generic resource loader, not used by `show`/`find_issue`).
- config/routes.rb: `resources :issues do member ... end` block at line 238; existing member routes `edit` (patch) and `tab/:name` (as `tab`); `/issues/preview` is a separate, unrelated route (`previews#issue`, line 41) and must not be reused.
- Entry points: `IssuesController#show` (app/controllers/issues_controller.rb:102), `ApplicationController#find_issue` (app/controllers/application_controller.rb:418), `ApplicationController#authorize` (app/controllers/application_controller.rb:346).
- Depends on this area: none outside the area found by the graph (`affected IssuesController` and `affected ApplicationController` return only other controllers inheriting from `ApplicationController`; no edge to `app/models` or `app/views` because the graph does not resolve Ruby's dynamic `@issue.method` calls or ERB rendering).

Source: commit 53abb0a6c4107c996ee4d478e1f50441f6328912
Graph queries: god-nodes areas/controllers: ApplicationController (126 edges, generic base), IssuesController (23 edges) — both in Code map; affected IssuesController --depth 2: no affected nodes (no edges in, as expected for a leaf controller); affected ApplicationController --depth 2: 36 dependents, all other `*Controller` classes inheriting it (outside this area's scope, e.g. app/controllers/account_controller.rb:20) — confirms `ApplicationController` is a generic hub, not an issues-specific dependency; affected find_issue --depth 2: ambiguous/no unique node match (method name not resolved standalone in the graph) — confirmed by reading application_controller.rb:418 instead.
