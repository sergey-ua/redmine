# issues Specification

## Purpose
The issues domain serves Redmine's issue pages: the full issue page (`IssuesController#show`) and the
read-only HTML fragments that the page loads separately (`IssuesController#issue_tab`). This spec
documents how a read-only fragment endpoint on `IssuesController` behaves today — how it is routed,
how the issue is looked up and scoped to what the user may see, how permission is enforced, how the
fragment is rendered without a layout, and how issue descriptions are rendered so that inline images
and wiki macros resolve. It is the behaviour a new read-only endpoint must fit into.

## Requirements

### Requirement: A read-only issue fragment is reached through a member route under `resources :issues`
The system SHALL route read-only per-issue fragment requests through a `member` route declared inside
the `resources :issues` block in `config/routes.rb`, so that the issue id arrives as `params[:id]` and
a named path helper is generated.

#### Scenario: the existing tab fragment route
- **WHEN** a request for `GET /issues/3/tab/time_entries` is routed
- **THEN** it dispatches to `issues#issue_tab` with `:id => '3'` and `:name => 'time_entries'`
  (`config/routes.rb:240`, asserted at `test/integration/routing/issues_test.rb:39`)

#### Scenario: a named path helper is generated from the route
- **WHEN** the route is declared with `:as => 'tab'` inside the `member do` block
- **THEN** `tab_issue_path` exists and is used to build the tab URLs
  (`app/helpers/issues_helper.rb:745`, `:757`)

#### Scenario: an id-less preview path is already taken by a different controller
- **WHEN** a request for `GET /issues/preview` is routed
- **THEN** it dispatches to `previews#issue` (`config/routes.rb:41`), which previews *unsaved submitted
  text* rather than a stored issue (`app/controllers/previews_controller.rb:24-31`)
- **AND** a `member` route of the form `/issues/:id/preview` does not collide with it, because the
  existing route has no `:id` segment and is declared earlier in the file than `resources :issues`
  (`config/routes.rb:41` before `:238`)

### Requirement: The issue is looked up by a shared filter that enforces visibility
The system SHALL look up the issue for per-issue actions through `ApplicationController#find_issue`,
listed in `before_action :find_issue, :only => [...]`, which sets `@issue` and `@project` and refuses
issues the current user may not see.

#### Scenario: the filter list is what grants an action its issue
- **WHEN** `IssuesController` is loaded
- **THEN** `before_action :find_issue, :only => [:show, :edit, :update, :issue_tab]` names exactly the
  actions that receive `@issue` and `@project` (`app/controllers/issues_controller.rb:23`)
- **AND** an action absent from that list has neither instance variable set

#### Scenario: a visible issue is loaded together with its project
- **WHEN** `find_issue` runs for an issue the user may see
- **THEN** `@issue` is the issue and `@project` is `@issue.project`
  (`app/controllers/application_controller.rb:418-425`)

#### Scenario: an issue the user may not see is refused, not hidden
- **WHEN** the issue exists but `@issue.visible?` is false
- **THEN** `find_issue` raises `Unauthorized` (`app/controllers/application_controller.rb:421`), which
  `rescue_from ::Unauthorized, :with => :deny_access` (`:67`) turns into 403 for a logged-in user and a
  login redirect for an anonymous one (`:340-342`)
- **AND** the lookup deliberately uses `Issue.find` rather than `Issue.visible.find` so that this
  distinction is possible (comment at `app/controllers/application_controller.rb:416-417`)

#### Scenario: a missing issue is a 404
- **WHEN** no issue has the given id
- **THEN** `ActiveRecord::RecordNotFound` is rescued into `render_404`
  (`app/controllers/application_controller.rb:424-425`)

#### Scenario: private issues are filtered per role
- **WHEN** `@issue.visible?` is evaluated
- **THEN** it layers the role's `issues_visibility` setting (all / default / own) on top of the
  `:view_issues` permission (`app/models/issue.rb:181-193`)

### Requirement: Every action on IssuesController except index, new and create is permission-gated
The system SHALL run `ApplicationController#authorize` before every `IssuesController` action other
than `index`, `new` and `create`, so a newly added action is permission-gated without any filter
change.

#### Scenario: the blanket filter
- **WHEN** `IssuesController` is loaded
- **THEN** `before_action :authorize, :except => [:index, :new, :create]` is declared
  (`app/controllers/issues_controller.rb:25`)

#### Scenario: denial is reported differently per cause
- **WHEN** `authorize` finds the user not allowed
- **THEN** an archived project yields `render_403` with `:notice_not_authorized_archived_project`
  (`app/controllers/application_controller.rb:353-355`); a project whose module is disabled yields a
  plain `render_403` (`:356-358`); otherwise `deny_access` runs (`:359`)

### Requirement: An action is authorized only if it is registered in the access-control action map
The system SHALL authorize a controller action only when the string `"{controller}/{action}"` appears
in the action map of some `map.permission` declaration; an unregistered action name is denied.

#### Scenario: the chain that resolves a permission
- **WHEN** `authorize` runs
- **THEN** it calls `User.current.allowed_to?({:controller => ctrl, :action => action}, @project)`
  (`app/controllers/application_controller.rb:347`), which calls `Project#allows_to?`
  (`app/models/user.rb:852`) → `Project#allowed_actions` (`app/models/project.rb:780`, `:1352-1356`) →
  `Redmine::AccessControl.allowed_actions` (`lib/redmine/access_control.rb:41-44`) → the
  `"{controller}/{action}"` strings built from each `map.permission` hash
  (`lib/redmine/access_control.rb:105-118`)

#### Scenario: an unregistered action is denied for everyone, including administrators
- **WHEN** an action name appears in no `map.permission` action map and is requested in a project context
- **THEN** it is in no role's `allowed_actions` and in no project's `allowed_actions`, so `allows_to?`
  returns false
- **AND** the user is denied even if `admin?`, because `return false unless context.allows_to?(action)`
  (`app/models/user.rb:852`) precedes `return true if admin?` (`:854`)

#### Scenario: the read-only issue actions registered today
- **WHEN** `lib/redmine/preparation.rb` is loaded
- **THEN** `map.permission :view_issues` lists `:issues => [:index, :show, :issue_tab]` under
  `project_module :issue_tracking` (`lib/redmine/preparation.rb:56-58`)
- **AND** the permission is declared `:read => true` (`lib/redmine/preparation.rb:66`)

#### Scenario: the issue tracking module must be enabled
- **WHEN** a project has the `issue_tracking` module disabled
- **THEN** `:view_issues` is not in `Project#allowed_permissions`, which is derived from the enabled
  module names (`app/models/project.rb:1340-1350`), so every action it covers is denied

#### Scenario: on a closed project only read permissions survive
- **WHEN** the project is closed (not active, not archived)
- **THEN** `allows_to?` returns false unless `Redmine::AccessControl.read_action?(action)`
  (`app/models/project.rb:773-776`), which is true only for actions covered by a permission declared
  `:read => true` (`lib/redmine/access_control.rb:58-68`, `:110`)

#### Scenario: on an archived project nothing is allowed
- **WHEN** the project is archived
- **THEN** `allows_to?` returns false for every action (`app/models/project.rb:769-772`)

### Requirement: A read-only issue fragment renders a partial with no layout
The system SHALL render read-only issue fragments with `render :partial`, which applies no layout, and
SHALL pass the fragment's data as `:locals`.

#### Scenario: the tab fragment renders a layout-less partial
- **WHEN** `issue_tab` is requested with `:name => 'time_entries'`
- **THEN** it renders `:partial => 'issues/tabs/time_entries'` with
  `:locals => {:time_entries => @time_entries}` and no `:layout` option, so no `base` layout is applied
  (`app/controllers/issues_controller.rb:264-265`)

#### Scenario: no format negotiation is performed
- **WHEN** `issue_tab` renders
- **THEN** there is no `respond_to` block (`app/controllers/issues_controller.rb:257-271`), so the same
  HTML partial is returned whatever format was requested — the functional test passes `format: 'js'`
  and asserts HTML (`test/functional/issues_controller_test.rb:3423-3430`)
- **AND** `issue_tab` is absent from `accept_api_auth` (`app/controllers/issues_controller.rb:29`), so
  it is not part of the API surface

### Requirement: The tab fragment endpoint is restricted to XHR requests
The system SHALL refuse a non-XHR request to `issue_tab` with status 422 before doing any work.

#### Scenario: a non-XHR request is refused
- **WHEN** `issue_tab` is requested and `request.xhr?` is false
- **THEN** it returns `render_error :status => 422` and renders nothing else
  (`app/controllers/issues_controller.rb:258`)
- **AND** for an HTML request `render_error` renders `common/error` inside the full `base` layout,
  because `use_layout` returns `'base'` for a non-XHR request
  (`app/controllers/application_controller.rb:636-638`, `:667-669`)

#### Scenario: an XHR request proceeds
- **WHEN** the request carries `X-Requested-With` (set by the jQuery call in
  `app/assets/javascripts/application-legacy.js:458-478`)
- **THEN** the gate passes and the fragment is rendered
  (`test/functional/issues_controller_test.rb:2914-2920` drives it with `:xhr => true`)

#### Scenario: an unrecognised tab name falls through to a 404
- **WHEN** `params[:name]` is neither `time_entries` nor `changesets`
- **THEN** the `case` renders nothing, Rails implicitly renders the non-existent `issues/issue_tab`
  template, and `rescue_from ::ActionView::MissingTemplate`
  (`app/controllers/application_controller.rb:68`) turns it into `render_404`
  (`:644-648`) — emergent behaviour, not a deliberate branch

### Requirement: Issue descriptions are rendered through textilizable with the issue's attachments
The system SHALL render an issue description with
`textilizable @issue, :description, :attachments => @issue.attachments`, which resolves wiki links,
inline attachment images and macros.

#### Scenario: the issue page renders the description
- **WHEN** `@issue.description?` is true on the issue page
- **THEN** the description is rendered inside a `div.wiki` with
  `textilizable @issue, :description, :attachments => @issue.attachments`
  (`app/views/issues/show.html.erb:110-121`)

#### Scenario: the object/attribute pair selects the text, the project context and the cache key
- **WHEN** `textilizable` is called with an object and an attribute
- **THEN** it reads `obj.send(attr).to_s` (`app/helpers/application_helper.rb:963-975`), returns `''`
  for blank text (`:976`) and an `html_safe` String otherwise (`:1008`)
- **AND** the project context for `[[wiki link]]` and `#123` resolution is
  `options[:project] || @project || obj.try(:project)` (`:978`)
- **AND** the object and attribute form the formatted-text cache key
  (`:987`, `lib/redmine/wiki_formatting.rb:89-111`), so the same pair shares a cache entry with the
  issue page

#### Scenario: inline attachments and macros resolve
- **WHEN** `:attachments` is passed
- **THEN** it is used by `parse_redmine_links` (`app/helpers/application_helper.rb:1336-1343`) and by
  `InlineAttachmentsScrubber` (`lib/redmine/wiki_formatting/inline_attachments_scrubber.rb:29-37`),
  both of which also append `obj.attachments` when the object responds to it
- **AND** macros are extracted by `catch_macros` (`app/helpers/application_helper.rb:981`, `:1487-1500`)
  and executed by `inject_macros` (`:1019`, `:1503-1520`)

#### Scenario: no controller-side setup is needed for textilizable itself
- **WHEN** a fragment rendered outside the issue page calls `textilizable`
- **THEN** the helper is available because it is defined in `ApplicationHelper`
  (`app/helpers/application_helper.rb:963`) and sets `@only_path`, `@parsed_headings` and
  `@heading_anchors` itself (`:979`, `:990-992`)
- **AND** no `@journals` is required by `textilizable`; `@journals` is required only by the other
  helpers the issue page calls around it (`journals_by_attachment_id(@journals)` at
  `app/views/issues/show.html.erb:126`), which `issue_tab` does not set

#### Scenario: the thumbnail macro keys off the literal action name "preview"
- **WHEN** the `{{thumbnail}}` macro runs
- **THEN** it widens its attachment lookup when
  `(controller_path == 'previews' || action_name == 'preview') && @attachments.present?`
  (`lib/redmine/wiki_formatting/macros.rb:342-344`)
- **AND** on a controller with no `find_attachments` filter `@attachments` is nil, so the branch is
  inert — but the coupling is by action name, so an action named `preview` matches that string

### Requirement: Rendering an issue read-only performs no write
The system SHALL not create a journal, save the issue or enqueue mail on any read-only render path.

#### Scenario: the tab fragment only reads
- **WHEN** `issue_tab` runs
- **THEN** it issues only reads — `@issue.time_entries.visible.preload(...)`
  (`app/controllers/issues_controller.rb:264`) and `@issue.changesets.visible.preload(...)` (`:268`) —
  and calls neither `save` nor `init_journal`

#### Scenario: journals and mail are reachable only from write actions
- **WHEN** a journal is created
- **THEN** `init_journal` is called only from the write paths — `app/controllers/issues_controller.rb:413`
  (bulk update), `:579` and `:609` (`update`)
- **AND** notification mail is delivered from model commit callbacks only:
  `Issue after_create_commit :send_notification` (`app/models/issue.rb:132`, delivering at `:2123`) and
  `Journal after_create_commit :send_notification` (`app/models/journal.rb:66`, delivering at `:389`),
  none of which is reachable without a save

#### Scenario: the only write a render may perform is to the formatted-text cache
- **WHEN** `textilizable` renders long text and `Setting.cache_formatted_text?` is on
- **THEN** the rendered HTML is written to the formatted-text cache
  (`lib/redmine/wiki_formatting.rb:91-97`) — a cache write, not a database or mail write
- **AND** `textilizable` mutates only a local copy of the text (`text = text.dup`,
  `app/helpers/application_helper.rb:980`)

### Requirement: No user-facing string is hard-coded in an issue fragment
The system SHALL take every user-facing string in an issue view or fragment from a locale key via
`l(:key)`, with the key defined in `config/locales/en.yml`.

#### Scenario: the existing fragments use locale keys only
- **WHEN** `app/views/issues/tabs/_time_entries.html.erb` renders
- **THEN** its labels come from `l(:button_edit)`, `l(:button_delete)`, `l(:text_are_you_sure)`,
  `l(:label_time_entry_plural)` and `l(:label_added_time_by)` (`:10-24`), all defined in
  `config/locales/en.yml` (e.g. `label_added_time_by` at `:967`, `label_time_entry_plural` at `:1032`)

#### Scenario: keys that already exist for preview-style wording
- **WHEN** a new fragment needs the wording the ticket names
- **THEN** `config/locales/en.yml` already defines `label_preview: Preview` (`:902`),
  `button_close: Close` (`:1272`), `label_none: none` (`:798`), `label_nobody: nobody` (`:801`),
  `field_description: Description` (`:290`) and `label_no_data: No data to display` (`:738`)

### Requirement: Issue list columns, not template markup, drive exports and saved queries
The system SHALL propagate a column into CSV export, PDF export, the column-selection UI and saved
queries only when it is registered in the query column model; markup added directly to a template does
not enter any of those paths.

#### Scenario: what a registered column reaches
- **WHEN** a column is present in `IssueQuery#available_columns`
  (`app/models/issue_query.rb:302-347`, base list at `:25`, `add_available_column` at
  `app/models/query.rb:804`)
- **THEN** it flows into `Query#columns` (`app/models/query.rb:819-827`) and `inline_columns`
  (`:829-831`), into CSV headers and cells via `query_to_csv` iterating `query.columns`
  (`app/helpers/queries_helper.rb:330-341`), into PDF table width and cells
  (`lib/redmine/export/pdf/issues_pdf_helper.rb:254-278`, `:555-559`), and into a saved query's
  persisted `column_names` (`app/models/query.rb:823`)

#### Scenario: a control that is template markup only stays out of them
- **WHEN** a control is rendered as markup in a template and registered in no column model
- **THEN** it appears in no CSV header or cell, consumes no PDF table width, cannot be selected into a
  saved query's `column_names`, and needs no handling for existing saved queries

### Requirement: Decisions a person confirmed about the read-only preview endpoint
These three points were asked as a decision batch on the ticket and answered by a person on
2026-10-23 (`Q1 A, Q2 A, Q3 A`). A read-only preview endpoint added to this domain SHALL follow them.

#### Scenario: the preview action is registered under the existing `:view_issues` permission
- **WHEN** a read-only preview action is added to `IssuesController`
- **THEN** its name SHALL also be added to the `:issues` action list of `map.permission :view_issues`
  in `lib/redmine/preparation.rb:56-58`, alongside `:index`, `:show` and `:issue_tab`
- **AND** it SHALL NOT be given a permission of its own, so no existing role has to be edited and no
  new user-visible permission setting appears
- **AND** the endpoint is therefore reachable by anyone who may view issues, honours the
  `issue_tracking` module and works on closed projects (`:read => true`), exactly like `issue_tab`
- **AND** without that registration the endpoint would be denied for every user including
  administrators, as the access-control requirement above states

#### Scenario: the action is named `preview`
- **WHEN** the action and its member route are named
- **THEN** the name SHALL be `preview`, giving `GET /issues/:id/preview`, matching the name of the
  feature in the interface
- **AND** the two recorded overlaps are accepted as naming hazards rather than defects: the id-less
  `GET /issues/preview` → `previews#issue` route does not collide, and the `{{thumbnail}}` macro's
  `action_name == 'preview'` branch is inert because the action has no `find_attachments` filter and so
  no `@attachments`

#### Scenario: the preview endpoint serves any GET, with no XHR gate
- **WHEN** a non-XHR `GET /issues/:id/preview` arrives
- **THEN** the fragment SHALL be rendered, not refused — `issue_tab`'s `request.xhr?` / 422 gate
  (`app/controllers/issues_controller.rb:258`) SHALL NOT be copied
- **AND** the endpoint stays directly openable and linkable for debugging, while the `find_issue`
  visibility check and the `authorize` permission check still apply in full
- **AND** this is safe because the request is a plain GET with no side effects and the response is a
  bare layout-less fragment, so the gate would not be a security control

## Code map
- `app/controllers/issues_controller.rb`: the issues controller; declares the `find_issue` and
  `authorize` filter lists and holds `show` and the read-only `issue_tab` fragment action.
- `app/controllers/application_controller.rb`: shared filters and error handling — `find_issue`,
  `authorize`, `deny_access`, `render_error`, `use_layout`, and the `Unauthorized` /
  `ActionView::MissingTemplate` rescues.
- `config/routes.rb`: the `resources :issues ... member do` block (`:238-243`) that carries per-issue
  routes, and the earlier id-less `/issues/preview` → `previews#issue` route (`:41`).
- `lib/redmine/preparation.rb`: the permission map; `map.permission :view_issues` (`:58`) lists the
  issue actions that are authorized at all, and declares the permission `:read => true` (`:66`).
- `lib/redmine/access_control.rb`: turns a permission's action hash into `"controller/action"` strings
  and answers `read_action?`.
- `app/models/user.rb`, `app/models/project.rb`, `app/models/role.rb`: the three layers
  `authorize` consults — user/admin, project module and archived/closed state, role permissions.
- `app/models/issue.rb`: `Issue#visible?` (role `issues_visibility`) and the notification callback.
- `app/views/issues/show.html.erb`: the full issue page; `:119` is the description-rendering pattern.
- `app/views/issues/_attributes.html.erb`: the editable attribute block of the issue form (status,
  priority, assignee, category) — the edit-side counterpart of a read-only summary block.
- `app/views/issues/tabs/_time_entries.html.erb`, `_changesets.html.erb`: the fragments `issue_tab`
  renders; the precedent for a layout-less issue fragment.
- `app/helpers/application_helper.rb`: `textilizable` (`:963`) and `parse_redmine_links` (`:1336`).
- `app/helpers/issues_helper.rb`: `issue_history_tabs` (`:737-760`), which builds the remote tab links.
- `app/models/issue_query.rb`, `app/models/query.rb`, `app/helpers/queries_helper.rb`,
  `lib/redmine/export/pdf/issues_pdf_helper.rb`: the column model and the export paths it feeds.
- `config/locales/en.yml`: the reference locale; every user-facing string's key.
- Entry points:
  - `IssuesController` (`app/controllers/issues_controller.rb:20`)
  - `IssuesController#show` (`app/controllers/issues_controller.rb:102`)
  - `IssuesController#issue_tab` (`app/controllers/issues_controller.rb:257`)
  - `ApplicationController` (`app/controllers/application_controller.rb:25`)
  - `ApplicationController#authorize` (`app/controllers/application_controller.rb:346`)
  - `ApplicationController#find_issue` (`app/controllers/application_controller.rb:418`)
  - `ApplicationHelper#textilizable` (`app/helpers/application_helper.rb:963`)
  - `resources :issues ... member` route block (`config/routes.rb:238-243`) — not in the graph, read
    from the file
- Depends on this area:
  - `ApplicationController` → 37 subclasses by `[inherits]`, every controller in the application,
    including `app/controllers/issues_controller.rb:20`, `app/controllers/journals_controller.rb:20`,
    `app/controllers/queries_controller.rb:20`, `app/controllers/context_menus_controller.rb`,
    `app/controllers/previews_controller.rb`, `app/controllers/timelog_controller.rb:20`,
    `app/controllers/attachments_controller.rb:20` — all outside this area's paths, so a change to a
    shared `ApplicationController` filter affects the whole application and must be additive.
  - `ApplicationController#authorize` → `.authorize_global()`
    (`app/controllers/application_controller.rb:365`) and `.find_optional_project()`
    (`app/controllers/application_controller.rb:393`) — inside this area.
  - `IssuesController`, `IssuesController#show`, `IssuesController#issue_tab` and
    `ApplicationController#find_issue` → none. `issue_tab` has one outgoing edge only, to
    `.render_error()` (`app/controllers/issues_controller.rb:258`).
  - Not visible to the graph, confirmed by reading the files: `app/views/issues/show.html.erb:119`
    depends on `textilizable`; `app/helpers/issues_helper.rb:745`, `:757` depend on the `tab` route;
    `lib/redmine/preparation.rb:58` names `issue_tab`;
    `app/assets/javascripts/application-legacy.js:458-478` calls the tab endpoint;
    `test/integration/routing/issues_test.rb:39` and
    `test/functional/issues_controller_test.rb:2914`, `:3423`, `:3444` exercise it.
- Tests covering this area:
  - `test/integration/routing/issues_test.rb:39` — the `issue_tab` route.
  - `test/functional/issues_controller_test.rb` — `test_show_should_display_visible_changesets_from_other_projects`
    (`:2904`), `test_show_render_changeset_comments_in_original_context` (`:3417`),
    `test_show_should_display_spent_time_tab_for_issue_with_time_entries` (`:3434`): all drive
    `issue_tab` with `:xhr => true` and assert fragment content with `assert_select`.
  - No test covers `issue_tab`'s non-XHR 422 branch, its unknown-tab-name 404, an invisible issue, or a
    project with `issue_tracking` disabled. The precedent is strong on fragment content and weak on
    negative cases.

Source: commit 53abb0a6c4107c996ee4d478e1f50441f6328912
Graph queries: `affected "IssuesController" --depth 2`: no affected nodes; `affected "ApplicationController" --depth 2`: 37 dependents, all `[inherits]` subclasses, all outside this area (activities_controller.rb:20, admin_controller.rb:20, journals_controller.rb:20, queries_controller.rb:20, timelog_controller.rb:20, attachments_controller.rb:20, …); `affected ".show()" --depth 2`: no affected nodes; `affected "areas-3::issues_controller_issuescontroller_issue_tab" --depth 2`: no affected nodes; `affected "areas-3::application_controller_applicationcontroller_find_issue" --depth 2`: no affected nodes; `affected "areas-3::application_controller_applicationcontroller_authorize" --depth 2`: 2 dependents, both inside the area (application_controller.rb:365 `authorize_global`, application_controller.rb:393 `find_optional_project`); `explain "issue_tab"`: app/controllers/issues_controller.rb:257, degree 2, one outgoing edge to `.render_error()` at :258; `explain "find_issue"` and `explain "authorize"`: ambiguous (exit 3), disambiguated to the `application_controller.rb` node ids above; `path "issue_tab" "textilizable"`: no directed path found — expected, because Graphify skips all `.erb` files and does not model the Rails route DSL, so `textilizable`'s call sites in templates and the `resources :issues ... member do` block have no nodes and were read from `app/views/issues/show.html.erb:119` and `config/routes.rb:238-243` instead. `god-nodes` for this area was run by the assess step: hubs `ApplicationController` (app/controllers/application_controller.rb:25) and `IssuesController` (app/controllers/issues_controller.rb:20), both now in this Code map.
