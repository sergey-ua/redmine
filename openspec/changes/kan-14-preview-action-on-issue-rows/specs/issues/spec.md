# Spec Delta

## ADDED Requirements

### Requirement: A fixed Preview cell appears on every issue row of the issue list
The system SHALL render, on every row of the project issue list and the global issue list, a
labelled Preview control in a fixed cell that is not part of the query column model, with a matching
empty header cell, and SHALL keep group rows and block-column rows spanning the whole table.

#### Scenario: Every row of both lists carries the control
- **WHEN** the project issue list or the global issue list is rendered with at least one issue
- **THEN** each issue row carries one Preview control, labelled from a locale key, in a cell that
  follows the existing buttons cell
- **AND** both lists show it, because one shared list partial and one shared page serve both
  surfaces

#### Scenario: The header cell is empty
- **WHEN** the table header is rendered
- **THEN** the Preview cell's header carries no caption, matching the existing buttons header cell
- **AND** a caption there would be counted as a column by the suite's header-reading helper, which
  drops blank headers, so the cell MUST stay empty

#### Scenario: The cell is hidden in print output
- **WHEN** the issue list is printed
- **THEN** the Preview cell is not printed, like the two older fixed cells

#### Scenario: Group rows and block-column rows still span the table
- **WHEN** the query is grouped, or a block column has content
- **THEN** the group header row and the block-column row each span every cell of the table,
  including the new fixed cell

#### Scenario: The control does not disturb row selection or the context menu
- **WHEN** the user clicks the Preview control, clicks a row checkbox, clicks the issue id or
  subject link, right-clicks a row, or runs a bulk action
- **THEN** each behaves exactly as it did before the Preview cell existed; in particular clicking
  Preview does not toggle the row's selection
- **AND** the control is therefore a link, which the legacy selection handler ignores; a control
  that is not a link would fall through into the row-selection branch and toggle the row

#### Scenario: The control is absent where no preview panel exists
- **WHEN** an issue table is rendered on a page that has no preview panel, such as a My page issue
  block
- **THEN** no Preview cell and no Preview control is rendered there, and that table is otherwise
  unchanged

### Requirement: GET /issues/:id/preview renders a layout-less issue fragment
The system SHALL serve a read-only HTML fragment for a single issue at `GET /issues/:id/preview`,
reachable by any user who may view that issue and refused to anyone else.

#### Scenario: The route reaches the action with the issue id
- **WHEN** `GET /issues/3/preview` is routed
- **THEN** it dispatches to the issues controller's `preview` action with `:id => '3'`, and a named
  path helper for it exists
- **AND** the existing id-less `GET /issues/preview` markup-preview route is unaffected

#### Scenario: Visibility and permission are inherited, not re-implemented
- **WHEN** the endpoint is requested
- **THEN** the issue is looked up by the shared `find_issue` filter, so an issue the user may not
  see is refused and an unknown id is a 404
- **AND** permission is enforced by the blanket `authorize` filter, so a user without
  `:view_issues` in that project is denied
- **AND** the action name is registered in the `:view_issues` action map, without which the endpoint
  would be denied to every user including administrators

#### Scenario: Any GET is served, with no XHR gate
- **WHEN** a non-XHR `GET /issues/:id/preview` arrives
- **THEN** the fragment is rendered rather than refused — the tab endpoint's XHR/422 gate is
  deliberately not copied, so the endpoint stays directly openable for debugging

#### Scenario: No layout and no format negotiation
- **WHEN** the action renders
- **THEN** it renders a partial, so no page layout is applied, and the response is the bare fragment
- **AND** no format negotiation is performed and the endpoint is not part of the API surface

### Requirement: The preview fragment shows a summary block and the rendered description
The system SHALL render in the preview fragment the issue's id, subject, project, tracker, status,
priority and assignee, an **Open full issue** link, a close control, and the issue's description
rendered as wiki-formatted text.

#### Scenario: A fully populated issue
- **WHEN** the fragment is rendered for an issue with an assignee and a description
- **THEN** it shows the issue id and subject in its header, the project, tracker, status, priority
  and assignee in a summary block, and the description rendered with inline attachment images and
  macros resolved, as the full issue page renders it

#### Scenario: An issue with no assignee
- **WHEN** the issue has no assignee
- **THEN** the assignee line reads **Unassigned**

#### Scenario: An issue with an empty description
- **WHEN** the issue's description is blank
- **THEN** the description area reads **No description** and no empty rendered-text block is shown

#### Scenario: Open full issue navigates to the issue page
- **WHEN** the user activates **Open full issue**
- **THEN** the browser navigates to the existing issue page for the previewed issue

### Requirement: The preview panel is populated client-side without navigating the list
The system SHALL fill a preview panel on the issue list page from the preview endpoint without
reloading or re-navigating the list document, and SHALL let the user dismiss the panel.

#### Scenario: Clicking Preview opens the panel over the list
- **WHEN** the user clicks the Preview control on a row
- **THEN** the issue's fragment is fetched and placed into the panel, the panel becomes visible, and
  the issue list is still displayed
- **AND** no page navigation occurs, so the list's filters, sort, page and scroll position are
  preserved

#### Scenario: Previewing a second issue replaces the panel contents
- **WHEN** the user clicks Preview on another row while the panel is open
- **THEN** the panel shows the newly requested issue, again without navigation

#### Scenario: The close control hides the panel
- **WHEN** the user activates the panel's close control
- **THEN** the panel is hidden and the list is left exactly as it was

#### Scenario: Panel placement on desktop and on narrow screens
- **WHEN** the viewport is desktop-width
- **THEN** the panel is docked to the right-hand edge of the main content area as a fixed overlay,
  leaving the page's column layout and its existing filters-and-saved-queries sidebar untouched
- **AND** on a narrow viewport the panel is a full-width block below the list instead

#### Scenario: The panel is not added to pages that have none
- **WHEN** a page other than the issue list renders an issue table
- **THEN** no preview panel and no preview client-side controller is present there

### Requirement: Preview introduces no new user-facing literal
The system SHALL take every string the Preview control, panel and fragment display from a locale key,
with the key defined in the English reference locale file.

#### Scenario: Every new string is a locale lookup
- **WHEN** the Preview control, the panel chrome and the fragment render
- **THEN** each user-facing string is read from a locale key and no literal user-facing text appears
  in any of the new or edited templates

#### Scenario: Only two strings need a new key
- **WHEN** the locale file is consulted for the wording the ticket names
- **THEN** keys for Preview, Close, Description, Assignee and Issue already exist and are reused
- **AND** no existing key has the value **Unassigned** or **No description**, so exactly two new keys
  are authored in the English reference locale, which every other language file mirrors

### Requirement: Verification
The system's Preview behaviour SHALL be proved by server-side and browser tests covering the
read-only guarantee, the two empty-value cases, visibility and permission, and the absence of
Preview from exports, the column picker and saved queries.

#### Scenario: Repeated previews write nothing
- **WHEN** a controller test requests the preview endpoint for the same issue several times
- **THEN** no journal is created, no notification mail is delivered, and the issue's attributes are
  unchanged when it is reloaded
- **AND** the assertions used are the suite's established ones for journal count and for the mail
  deliveries collection, with deliveries cleared before the requests

#### Scenario: Unassigned and No description are asserted on fixtures
- **WHEN** the endpoint is requested for a fixture issue with no assignee, and for a fixture issue
  with neither an assignee nor a description
- **THEN** the fragment contains **Unassigned**, and **No description** respectively

#### Scenario: Visibility and permission are asserted per login state
- **WHEN** the endpoint is requested by an anonymous user, by a logged-in user without permission on
  the project, and for an id no issue has
- **THEN** the responses are a login redirect, a 403, and a 404 respectively
- **AND** a test proves the action name is registered in the `:view_issues` action map, because
  without it the endpoint is denied to everyone

#### Scenario: Preview reaches no export, no column picker and no saved query
- **WHEN** an issue list is exported to CSV, exported to PDF, or its column-selection UI is rendered,
  and when an existing saved query is loaded
- **THEN** the CSV headers contain no Preview header, the available column list offers no Preview
  option, the saved query's stored column names are unchanged, and the PDF export still succeeds
- **AND** the PDF half is proved indirectly: the suite asserts only the media type and the file
  signature of a PDF response, so the claim rests on the column model plus a successful export

#### Scenario: The list page behaviour is proved in the browser
- **WHEN** the browser suite drives the issue list
- **THEN** clicking Preview populates the panel while the list URL does not change, the close control
  hides the panel, **Open full issue** navigates to the issue page, and the row checkbox, id link,
  subject link and right-click context menu still behave as before

#### Scenario: The My page is proved undisturbed
- **WHEN** the existing My page controller and browser tests are re-run
- **THEN** the My page issue blocks render as before, with no Preview cell and no change to their
  table structure

#### Scenario: The column model and the export helpers receive no change
- **WHEN** the change is complete
- **THEN** the query model, the issue query, the queries helper and the PDF issues export helper are
  byte-for-byte unchanged
- **AND** needing a change in any of them means Preview was implemented as a query column, which is
  a defect to report rather than to work around: the available-column list is a class attribute
  defined only by query subclasses, and the registration helper accepts only query-column objects,
  so template markup cannot enter the export, picker or saved-query paths

## MODIFIED Requirements

### Requirement: A read-only issue fragment is reached through a member route under `resources :issues`
The system SHALL route read-only per-issue fragment requests through a `member` route declared inside
the `resources :issues` block in `config/routes.rb`, so that the issue id arrives as `params[:id]` and
a named path helper is generated.

#### Scenario: the existing tab fragment route
- **WHEN** a request for `GET /issues/3/tab/time_entries` is routed
- **THEN** it dispatches to `issues#issue_tab` with `:id => '3'` and `:name => 'time_entries'`
  (`config/routes.rb:240`, asserted at `test/integration/routing/issues_test.rb:39`)

#### Scenario: the preview fragment route
- **WHEN** a request for `GET /issues/3/preview` is routed
- **THEN** it dispatches to `issues#preview` with `:id => '3'`, from a `get 'preview'` line declared
  in the same `member do` block as the tab route (`config/routes.rb:238-243`)

#### Scenario: a named path helper is generated from the route
- **WHEN** the route is declared with `:as => 'tab'` inside the `member do` block
- **THEN** `tab_issue_path` exists and is used to build the tab URLs
  (`app/helpers/issues_helper.rb:745`, `:757`)
- **AND** the `get 'preview'` member route likewise generates `preview_issue_path(issue)`, which the
  list row's Preview control uses

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
- **THEN** `before_action :find_issue, :only => [:show, :edit, :update, :issue_tab, :preview]` names
  exactly the actions that receive `@issue` and `@project`
  (`app/controllers/issues_controller.rb:23`)
- **AND** an action absent from that list has neither instance variable set
- **AND** `:preview` is in the list, which is what makes the preview endpoint respect issue
  visibility; nothing else is bypassed for it

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
- **THEN** `map.permission :view_issues` lists `:issues => [:index, :show, :issue_tab, :preview]`
  under `project_module :issue_tracking` (`lib/redmine/preparation.rb:56-58`)
- **AND** the permission is declared `:read => true` (`lib/redmine/preparation.rb:66`), so the preview
  endpoint also works on closed projects
- **AND** `preview` is given no permission of its own, so no existing role has to be edited and no new
  user-visible permission setting appears

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

#### Scenario: the preview fragment renders a layout-less partial
- **WHEN** `preview` is requested
- **THEN** it renders `:partial => 'issues/preview'` with no `:layout` option, so the response is the
  bare fragment the client-side controller swaps into the panel

#### Scenario: no format negotiation is performed
- **WHEN** `issue_tab` or `preview` renders
- **THEN** there is no `respond_to` block (`app/controllers/issues_controller.rb:257-271`), so the same
  HTML partial is returned whatever format was requested — the functional test passes `format: 'js'`
  and asserts HTML (`test/functional/issues_controller_test.rb:3423-3430`)
- **AND** both are absent from `accept_api_auth` (`app/controllers/issues_controller.rb:29`), so
  neither is part of the API surface

### Requirement: Rendering an issue read-only performs no write
The system SHALL not create a journal, save the issue or enqueue mail on any read-only render path.

#### Scenario: the tab fragment only reads
- **WHEN** `issue_tab` runs
- **THEN** it issues only reads — `@issue.time_entries.visible.preload(...)`
  (`app/controllers/issues_controller.rb:264`) and `@issue.changesets.visible.preload(...)` (`:268`) —
  and calls neither `save` nor `init_journal`

#### Scenario: the preview fragment only reads
- **WHEN** `preview` runs
- **THEN** it reads `@issue` and its associated project, tracker, status, priority, assignee and
  attachments only, and calls neither `save` nor `init_journal`, no matter how many times it is
  requested

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
  `field_description: Description` (`:290`), `field_assigned_to: Assignee` (`:323`),
  `label_issue: Issue` (`:654`) and `label_no_data: No data to display` (`:738`)

#### Scenario: the two strings that have no existing key
- **WHEN** the preview fragment needs the ticket's **Unassigned** and **No description** wording
- **THEN** no key in `config/locales/en.yml` has either value — the nearest existing keys are the
  lower-case `label_none: none` and `label_nobody: nobody` — so exactly two keys are authored new with
  the ticket's exact words, and `en.yml` stays the reference every other language file mirrors
