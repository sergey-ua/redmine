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

### Requirement: `find_issue` runs as a `before_action` for `quick_preview` too
The system SHALL run `find_issue` as a `before_action` for `quick_preview` (in addition to `show`, `edit`, `update`, `issue_tab`), and SHALL NOT run `authorize` for it (`quick_preview` is excluded from the `authorize` before_action's `:only => [:show, ...]`-equivalent — visibility is enforced solely via `find_issue`'s `raise Unauthorized unless @issue.visible?`).

#### Scenario: quick_preview enforces the same visibility check as show
- **WHEN** a user requests `quick_preview` for an issue they cannot see, or for an issue id that does not exist
- **THEN** the controller responds the same way `show` would: `Unauthorized`/`deny_access` (403) for a non-visible issue, or `render_404` for a missing one

### Requirement: `quick_preview` and `find_issue` never alter the list's session state
`quick_preview` (`app/controllers/issues_controller.rb:257`) SHALL only set `@issue`/`@project` (via `find_issue`) and render a JS partial; it SHALL NOT read or write `session[:issue_query]` (or any other `<klass>_query` session key), the sort session key written by `sort_helper.rb`, or `session[:per_page]`. Those session keys are written only by `retrieve_query` (`app/helpers/queries_helper.rb:352`, invoked from `index`-style list actions) and the sort/pagination helpers invoked alongside it. `find_issue` (`app/controllers/application_controller.rb:418`) sets only `@issue` and `@project` and performs no session access.

#### Scenario: Opening, switching, or closing a preview leaves the list query state unchanged
- **WHEN** a user has a list open with filters, sort, and pagination set (stored in `session[:issue_query]` and related session keys) and then requests `quick_preview` for an issue (opening, or switching to, a preview)
- **THEN** `session[:issue_query]` and the sort/pagination session state are byte-for-byte unchanged after the request
- **AND** a subsequent re-render of the list (`index`) reflects the same filters, sort, and pagination as before the preview request

### Requirement: `show` builds the full issue page from `@issue`
The system SHALL build `@issue`'s header, summary fields and description for the full page view after the before_action chain succeeds.

`show` (`app/controllers/issues_controller.rb:102`) uses `@issue.visible_journals_with_index`, `@issue.relations`, `@issue.new_statuses_allowed_to`, and renders `app/views/issues/show.html.erb`, which reads summary fields directly off `@issue` (status, priority, assigned_to, category, fixed_version, dates, done_ratio, estimated_hours) guarded by `@issue.disabled_core_fields.include?(...)` and the description via `textilizable @issue, :description, ...` guarded by `@issue.description?`.

#### Scenario: A field disabled for the issue's tracker is not shown
- **WHEN** the issue's tracker disables a core field (e.g. `priority_id` is in `@issue.disabled_core_fields`)
- **THEN** `show.html.erb` skips that field's row entirely; it is not rendered with a blank or placeholder value.

## Code map
- app/controllers/issues_controller.rb: `IssuesController`; `before_action :find_issue, :only => [:show, :edit, :update, :issue_tab, :quick_preview]` and `before_action :authorize, :except => [:index, :new, :create]` at lines 22-24; `show` action at line 102; `quick_preview` action at line 257 (`respond_to { |format| format.js }`, renders `app/views/issues/quick_preview.js.erb`).
- app/controllers/application_controller.rb: `find_issue` (line 418, loads `@issue`/`@project`, raises `Unauthorized` unless `@issue.visible?`, no session access); `authorize` (line 346, checks the `:view_issues`-style permission map, renders 403/`deny_access`, not run for `quick_preview`); `find_model_object` (line 406, generic resource loader, not used by `show`/`find_issue`/`quick_preview`).
- app/helpers/queries_helper.rb: `retrieve_query` (line 352) — the sole writer of `session[:issue_query]` (and other `<klass>_query` session keys); invoked only from list actions such as `index`, never from `quick_preview`.
- app/helpers/sort_helper.rb: sort session writer (around line 85) — invoked only alongside list actions, never from `quick_preview`.
- config/routes.rb: `resources :issues do member ... end` block at line 238; existing member routes `edit` (patch), `tab/:name` (as `tab`), and `quick_preview` (`get 'quick_preview'`, see `lib/redmine/preparation.rb:58` for its `:view_issues` permission mapping); `/issues/preview` is a separate, unrelated route (`previews#issue`, line 41) and must not be reused.
- Entry points: `IssuesController#show` (app/controllers/issues_controller.rb:102), `IssuesController#quick_preview` (app/controllers/issues_controller.rb:257), `ApplicationController#find_issue` (app/controllers/application_controller.rb:418), `ApplicationController#authorize` (app/controllers/application_controller.rb:346).
- Depends on this area: none outside the area found by the graph. `affected .quick_preview() --depth 2`: no affected nodes (nothing calls into or depends on `quick_preview`, confirming it is a leaf action). `affected ApplicationController#find_issue --depth 2`: no affected nodes. `affected IssuesController` and `affected ApplicationController` return only other controllers inheriting from `ApplicationController`; no edge to `app/models` or `app/views` because the graph does not resolve Ruby's dynamic `@issue.method` calls or ERB rendering.

Source: commit dd0c57557a1bedce158a2af8d9d5fcd8453c4735
Graph queries: god-nodes areas/controllers: ApplicationController (126 edges, generic base), IssuesController (23 edges) — both in Code map; affected IssuesController --depth 2: no affected nodes (no edges in, as expected for a leaf controller); affected ApplicationController --depth 2: 36 dependents, all other `*Controller` classes inheriting it (outside this area's scope, e.g. app/controllers/account_controller.rb:20) — confirms `ApplicationController` is a generic hub, not an issues-specific dependency; affected ".quick_preview()" --depth 2: no affected nodes found (leaf action, nothing depends on it) — this is the basis for the list-state-isolation requirement above; path from quick_preview to index: no directed path found (confirms no call chain from quick_preview into the list/query machinery); affected find_issue --depth 2: ambiguous/no unique node match for the bare name, resolved via the full node id `ApplicationController#find_issue` which also returned no affected nodes — confirmed by reading application_controller.rb:418 instead.
