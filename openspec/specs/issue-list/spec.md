# issue-list Specification

## Purpose
The issue list is the HTML table that renders a set of issues selected by an `IssueQuery`. One
partial, `app/views/issues/_list.html.erb`, renders every issue table in the application; the
query's column model decides the middle columns, while the partial itself contributes two fixed
cells (a row checkbox and a buttons cell holding the context-menu trigger) that are not part of that
column model. `app/views/issues/index.html.erb` is the page around it and is shared by the project
issue list and the global issue list. Client-side behaviour is split between legacy jQuery
(`app/assets/javascripts/context_menu.js`, for selection and the right-click context menu) and
Stimulus controllers under `app/javascript/controllers/`, which are auto-registered by filename. All
user-facing strings come from `config/locales/en.yml` through the `l()` helper, and all styling from
`app/assets/stylesheets/application.css` with narrow-screen overrides in `responsive.css`.

## Requirements

### Requirement: One shared list partial renders every issue table
The system SHALL render issue tables from the single partial `app/views/issues/_list.html.erb`,
taking `issues` and `query` as locals and an optional `query_options` hash.

#### Scenario: Project and global issue lists use the same page
- **WHEN** `IssuesController#index` renders `app/views/issues/index.html.erb`
- **THEN** the page renders `issues/list` with `@issues` and `@query`
  (`app/views/issues/index.html.erb:33`), and the same action and view serve the global list with
  `@project` nil — the only differences are `@project`-conditional blocks in the page's contextual
  menu (`index.html.erb:2`, `:7`), so a change to the page affects both surfaces at once.

#### Scenario: The My page issue block also renders the partial
- **WHEN** the My page renders an issue query block
- **THEN** `app/views/my/blocks/_issues.erb:26` renders the same `issues/list` partial with its own
  `query`, `issues` and a `query_options` hash carrying `:sort_param` and `:sort_link_options`
  (`_issues.erb:30-33`)
- **AND** therefore any markup added to `_list.html.erb` appears on the My page as well, not only on
  the issue list page.

#### Scenario: query_options is optional
- **WHEN** the partial is rendered without a `query_options` local
- **THEN** `_list.html.erb:1-2` defaults it to `{}` before use.

### Requirement: The row has exactly two fixed cells outside the query column model
The system SHALL render, for each issue row, a leading `td.checkbox.hide-when-print` and a trailing
`td.buttons.hide-when-print`, neither of which is an `IssueQuery` column, with matching `th` cells in
the `thead`.

#### Scenario: Header row structure
- **WHEN** the `thead` is rendered
- **THEN** it emits `th.checkbox.hide-when-print` holding a `check_all` checkbox with class
  `toggle-selection` (`_list.html.erb:11-14`), then one `column_header(query, column, query_options)`
  per `query.inline_columns` (`:15-17`), then an empty `th.buttons.hide-when-print` (`:18`).

#### Scenario: Issue row structure
- **WHEN** an issue row is rendered
- **THEN** it is a `tr#issue-<id>` carrying class `hascontextmenu`, the `cycle('odd','even')` class,
  `issue.css_classes` and an `idnt idnt-<level>` class when the issue is nested (`:38`)
- **AND** it emits `td.checkbox.hide-when-print` with `check_box_tag("ids[]", issue.id, false)`
  (`:39`), then one `td` per `query.inline_columns` whose content is
  `column_content(column, issue)` and whose class is `column.css_classes` (`:40-42`), then
  `td.buttons.hide-when-print` containing `link_to_context_menu` (`:43`).

#### Scenario: Neither fixed cell is a query column
- **WHEN** a user picks columns for the query, or exports the query to CSV or PDF
- **THEN** the checkbox and buttons cells do not appear, because they exist only in this partial;
  the export paths iterate `query.inline_columns` (`lib/redmine/export/pdf/issues_pdf_helper.rb:275`,
  `:393`, `:429`, `:444`, `:534`) and `QueriesHelper#csv_content` / `#query_to_csv`
  (`app/helpers/queries_helper.rb:295`, `:330`) and never see them.

### Requirement: Group rows and block-column rows span the whole table
The system SHALL give group header rows and block-column rows a `colspan` equal to
`query.inline_columns.size + 2`, which is the inline column count plus the two fixed cells.

#### Scenario: Group header row
- **WHEN** the query is grouped and `grouped_issue_list` yields a `group_name`
- **THEN** a `tr.group.open` is emitted with a single
  `td colspan="<%= query.inline_columns.size + 2 %>"` (`_list.html.erb:25-26`) holding an expander
  (`toggleRowGroup(this)`), `span.name`, an optional `span.badge.badge-count.count`, `span.totals`
  and a collapse/expand-all link (`:27-34`), and `reset_cycle` is called first (`:24`).

#### Scenario: Block column row
- **WHEN** `query.block_columns` yields a column whose `column_content` is present
- **THEN** an extra `tr` is emitted after the issue row with a single
  `td colspan="<%= query.inline_columns.size + 2 %>"` whose class is
  `"<%= column.css_classes %> block_column"` (`:45-48`), prefixed by a `span` with the column caption
  only when more than one block column is shown (`:49-51`).

#### Scenario: The fixed-cell count is hard-coded in the functional tests
- **WHEN** the number of fixed cells changes
- **THEN** both `+ 2` expressions (`:26` and `:48`) have to change together, and so do the test
  assertions that spell the resulting numbers out as literals:
  `assert_select 'table.issues thead th', 4` at `test/functional/issues_controller_test.rb:1758`
  (its own comment reads `# columns: chekbox + id + subject`) and `:1783`, and
  `td.description[colspan="4"]` / `td.last_notes[colspan="4"]` at `:1759`, `:1785`, `:1787`, `:1824`,
  `:1835`, `:1847`, `:1848`, `:1869`. These line numbers and assertion texts were read from the
  test file; the suite was not executed in this step, because this clone has no
  `config/database.yml` and `bundle` cannot resolve the Gemfile in this environment.

### Requirement: Row selection, context menu and bulk actions are driven by the form and legacy jQuery
The system SHALL wrap the table in a `form_tag` carrying the context-menu URL and a `back_url`, and
drive selection and the context menu from `app/assets/javascripts/context_menu.js`.

#### Scenario: The form carries the context-menu URL and query state
- **WHEN** the partial renders
- **THEN** it opens `form_tag({}, :data => {:cm_url => issues_context_menu_path})`
  (`_list.html.erb:4`), emits a `back_url` hidden field built from `request.query_parameters`
  (`:5`) and `query_columns_hidden_tags(query)` (`:6`), and wraps the table in `div.autoscroll`
  (`:7`) with classes `list issues odd-even <%= query.css_classes %>` (`:8`).

#### Scenario: Right-click and the buttons cell both open the context menu
- **WHEN** the user right-clicks a row, or clicks the `a.js-contextmenu` that
  `link_to_context_menu` renders (`app/helpers/application_helper.rb:1634-1636`)
- **THEN** `contextMenuRightClick` runs (`context_menu.js:9`, bound at `:232-234`), finds the closest
  `.hascontextmenu` ancestor, and shows the menu; the required assets are included by the
  `context_menu` helper (`app/helpers/application_helper.rb:1708-1717`) which
  `index.html.erb:100` calls.

#### Scenario: Clicking a checkbox cell toggles selection
- **WHEN** the user clicks inside `td.checkbox`
- **THEN** `contextMenuClick` toggles the contained checkbox and adds or removes the
  `context-menu-selection` class on the row (`context_menu.js:36-48`); the header `check_all`
  checkbox toggles every `input[name=ids[]]` in the table through `toggleIssuesSelection`
  (`context_menu.js:239-242`)
- **AND** a click on an `a` that is not `.js-contextmenu` is ignored by the handler
  (`context_menu.js:11`), which is what lets the ID and subject links in the row navigate normally.

#### Scenario: ID and subject cells are links
- **WHEN** the `id` or `subject` column is rendered
- **THEN** `QueriesHelper#column_value` returns `link_to value, issue_path(item)` for both
  (`app/helpers/queries_helper.rb:258-261`), so the row's primary navigation is an ordinary link to
  the issue page.

### Requirement: Rows are produced by grouped_issue_list over the query results
The system SHALL iterate issues through `IssuesHelper#grouped_issue_list`, which yields each issue
with its nesting level and its group metadata.

#### Scenario: Yielded values
- **WHEN** `grouped_issue_list(issues, query)` runs (`app/helpers/issues_helper.rb:39-49`)
- **THEN** it delegates to `QueriesHelper#grouped_query_results` and yields
  `issue, ancestors.size, group_name, group_count, group_totals`, maintaining an `ancestors` stack so
  that `level` reflects the issue tree depth; the partial consumes exactly that signature
  (`_list.html.erb:22`).

#### Scenario: Cell content comes from the query column model
- **WHEN** a cell is rendered
- **THEN** `QueriesHelper#column_content(column, item)` (`queries_helper.rb:239-253`) resolves
  `column.value_object(item)`, joins array values with `', '`, delegates each value to
  `column_value` and fires the `:helper_queries_column_content` hook, so plugins can alter cell
  content.

### Requirement: Stimulus controllers are auto-registered by filename
The system SHALL load Stimulus controllers through importmap and register them by filename, so that
adding a controller file is sufficient to make it usable from markup.

#### Scenario: Loading chain
- **WHEN** a page loads the application JavaScript
- **THEN** `app/javascript/application.js:1` imports `"controllers"`;
  `app/javascript/controllers/index.js` (three lines) imports the shared `application` from
  `controllers/application` and calls `eagerLoadControllersFrom("controllers", application)`
  (`index.js:1-3`); `controllers/application.js:3-7` calls `Application.start()`, sets
  `application.debug = false` and exposes it as `window.Stimulus`.

#### Scenario: Registration requires no edit to index.js
- **WHEN** a new file `app/javascript/controllers/foo_bar_controller.js` is added
- **THEN** `pin_all_from "app/javascript/controllers", under: "controllers"`
  (`config/importmap.rb:9`) exposes it and `eagerLoadControllersFrom` registers it under the
  identifier `foo-bar`, usable as `data-controller="foo-bar"`; no registration line is added
  anywhere.

#### Scenario: The shape existing controllers follow
- **WHEN** a controller is written in this repository
- **THEN** it starts with the GPL header comment, imports `{ Controller } from "@hotwired/stimulus"`
  and exports an anonymous `default class extends Controller`
  (`issue_journal_link_controller.js:1-3`, `sticky_issue_header_controller.js:1-3`,
  `searchable_selection_controller.js:1-10`)
- **AND** declares DOM references as `static targets = [...]` and parameters as `static values = {...}`
  (`sticky_issue_header_controller.js:4`, `searchable_selection_controller.js:11-17`)
- **AND** uses `connect()` / `disconnect()` for lifecycle setup and teardown
  (`sticky_issue_header_controller.js:6-21`, `searchable_selection_controller.js:19-42`)
- **AND** binds user events declaratively from markup with `data-action="<event>-><identifier>#<method>"`
  rather than `addEventListener` (`app/views/watchers/_new.html.erb:47`,
  `app/views/layouts/base.html.erb:69`, `app/views/my/_sidebar.html.erb:38`)
- **AND** performs HTTP requests with `@rails/request.js` — `get` in
  `searchable_selection_controller.js:8`, `post` in `quote_reply_controller.js:3` — which is pinned
  as `requestjs-rails` in the Gemfile, not with bare `fetch`.

### Requirement: User-facing strings come from the English locale file
The system SHALL keep every user-facing string in `config/locales/en.yml` under a flat key in a
family (`label_*`, `button_*`, `field_*`, `text_*`) and reference it from views with `l(:key)`.

#### Scenario: Existing keys this area already uses
- **WHEN** the list and page render their own text
- **THEN** they use `l(:button_check_all)` / `l(:button_uncheck_all)` (`_list.html.erb:13`),
  `l(:button_collapse_all)` / `l(:button_expand_all)` (`:33`), `l(:button_actions)`
  (`application_helper.rb:1635`), and on the page `l(:label_issue_plural)`, `l(:label_no_data)`,
  `l(:field_summary)` and others (`index.html.erb:20`, `:30`, `:7`)
- **AND** no literal user-facing text appears in either template.

#### Scenario: Keys already present for the strings this area will need
- **WHEN** the locale file is consulted for the strings a preview control needs
- **THEN** `label_preview: Preview` already exists at `config/locales/en.yml:902`,
  `button_close: Close` at `:1272`, `button_actions: Actions` at `:1278` and `label_none: none` at
  `:798`; `field_description: Description` at `:290`. `en.yml` is the 1512-line reference locale and
  every other language file mirrors its keys.

### Requirement: Issue list styling lives in application.css with narrow-screen overrides in responsive.css
The system SHALL style the list from `app/assets/stylesheets/application.css` and override it for
narrow viewports from `app/assets/stylesheets/responsive.css`; there is no separate issue-list
stylesheet.

#### Scenario: Table cell rules
- **WHEN** the list table is styled
- **THEN** `application.css:557-586` holds the `table.list` rules, including
  `table.list td.checkbox { inline-size: 15px; ... }` (`:579`),
  `table.list td.buttons { white-space: nowrap; text-align: end; }` (`:581`) and the spacing of
  links inside the buttons cell (`:582-584`).

#### Scenario: Page layout containers
- **WHEN** a right-hand region is placed on the page
- **THEN** the available containers are `#main`, which is a flex row with
  `flex-direction: row-reverse` (`application.css:320`), `#sidebar`, which is the existing
  right-hand region with a width set per breakpoint (`:322-328`) and hidden by
  `#main.nosidebar #sidebar { display: none; }` (`:377`) or collapsed by
  `#main.collapsedsidebar` (`:378`), and `#content`, which is `flex-grow: 1` with `overflow-x: auto`
  (`:368-375`)
- **AND** the issue list page already occupies the sidebar: `index.html.erb:84-86` fills
  `content_for :sidebar` with `issues/sidebar`, so the sidebar is not free for a second panel.

#### Scenario: Narrow-screen behaviour
- **WHEN** the viewport is at most 899px wide (`responsive.css:34`)
- **THEN** `#sidebar` and `#sidebar-switch-panel` are hidden and moved into the mobile flyout menu
  (`responsive.css:221-224`), `#content` becomes full width (`:212-219`), and the issue-list
  breakpoint rules for this area start at the `/* issues page */` comment (`:731`) with
  `body.controller-issues p.query-totals` (`:732-735`) followed by the subtask/related-issue table
  rules (`:737` onward), which reposition `td.buttons` absolutely at the row's inline end
  (`:773-780`). A second narrower breakpoint exists at `max-width: 599px` (`:869`).

#### Scenario: Print output drops the fixed cells
- **WHEN** the page is printed
- **THEN** `@media print` hides `#sidebar` and `.contextual` entirely and applies
  `.hide-when-print { display: none !important; }` (`application.css:2683-2689`), which is why both
  fixed cells carry `hide-when-print`; a new fixed cell must carry it too or it will print.

### Requirement: /issues/preview is already taken by the markup preview
The system SHALL route `/issues/preview` to the markup/text preview controller, not to a
per-issue fragment.

#### Scenario: Existing route
- **WHEN** `/issues/preview` is requested
- **THEN** `config/routes.rb:41` matches it to `previews#issue` as `preview_issue` for GET, POST, PUT
  and PATCH — this is the live preview of wiki-formatted text in an issue form, and it is unrelated
  to a per-issue preview fragment, so a new per-issue endpoint needs a distinct route.

## Code map
- `app/views/issues/_list.html.erb`: the single issue table partial — form wrapper, thead, group
  rows, issue rows, block-column rows.
- `app/views/issues/index.html.erb`: the issue list page, shared by the project and global lists;
  renders the partial (`:33`), the query form, pagination, export options, the sidebar and
  `context_menu` (`:100`).
- `app/views/my/blocks/_issues.erb`: the My page block that also renders the partial (`:26`).
- `app/helpers/issues_helper.rb`: `issue_list` (`:27`), `grouped_issue_list` (`:39`),
  `render_issue_tooltip` (`:60`), `render_descendants_tree` (`:104`), `render_issue_relations`
  (`:235`).
- `app/helpers/queries_helper.rb`: `column_header` (`:203`), `column_content` (`:239`),
  `column_value` (`:255`), `grouped_query_results` (`:154`), `csv_content` (`:295`),
  `query_to_csv` (`:330`).
- `app/helpers/application_helper.rb`: `link_to_context_menu` (`:1634`), `context_menu` (`:1708`).
- `app/assets/javascripts/context_menu.js`: legacy jQuery selection and context menu
  (`contextMenuRightClick` `:9`, `contextMenuClick` `:23`, bindings `:232-234`,
  `toggleIssuesSelection` `:239`).
- `app/javascript/application.js` (`:1`), `app/javascript/controllers/index.js` (`:1-3`),
  `app/javascript/controllers/application.js` (`:1-8`): the Stimulus loading chain.
- `app/javascript/controllers/issue_journal_link_controller.js`,
  `sticky_issue_header_controller.js`, `searchable_selection_controller.js`,
  `quote_reply_controller.js`: the small-controller precedents for shape and for `@rails/request.js`.
- `config/importmap.rb:9`: `pin_all_from "app/javascript/controllers", under: "controllers"`.
- `config/locales/en.yml`: the reference locale, flat `label_*` / `button_*` / `field_*` / `text_*`
  keys.
- `app/assets/stylesheets/application.css`: `table.list` rules (`:557-586`), layout containers
  (`:320-378`), print block (`:2683-2692`).
- `app/assets/stylesheets/responsive.css`: `max-width: 899px` block (`:34`), content/sidebar
  overrides (`:207-229`), issues-page rules (`:731` onward), `max-width: 599px` block (`:869`).
- Tests: `test/functional/issues_controller_test.rb` (thead/colspan assertions at `:1758`, `:1759`,
  `:1783`, `:1785`, `:1787`, `:1824`, `:1835`, `:1847`, `:1848`, `:1869`; grouping assertions at
  `:360`, `:374`, `:388`, `:402`, `:420`, `:445`, `:467`), `test/functional/my_controller_test.rb:72`
  and `test/system/my_page_test.rb:31-79` (the partial on the My page),
  `test/system/issues_test.rb`, `test/system/sticky_issue_header_test.rb` (an existing
  Stimulus-controller system test).
- Entry points: `grouped_issue_list` (`app/helpers/issues_helper.rb:39`), `column_content`
  (`app/helpers/queries_helper.rb:239`), `column_header` (`app/helpers/queries_helper.rb:203`),
  `link_to_context_menu` (`app/helpers/application_helper.rb:1634`),
  `eagerLoadControllersFrom("controllers", application)`
  (`app/javascript/controllers/index.js:3`).
- Depends on this area:
  - `grouped_issue_list`: none outside the area (`affected --depth 2` found no dependents; the only
    caller is `_list.html.erb:22`, an ERB file that is not in the graph).
  - `column_content`: `render_descendants_tree` (`app/helpers/issues_helper.rb:145`) and
    `render_issue_relations` (`app/helpers/issues_helper.rb:248`) — both inside `app/helpers` but
    outside the list partial, so they render issue tables of their own and must be checked by any
    change to cell rendering.
  - `link_to_context_menu`: `render_descendants_tree` (`app/helpers/issues_helper.rb:138`),
    `render_issue_relations` (`app/helpers/issues_helper.rb:239`).
  - `QueriesHelper`: `IssuesHelper` (mixes_in, `app/helpers/issues_helper.rb:24`),
    `grouped_issue_list` (`issues_helper.rb:41`), `grouped_project_list`
    (`app/helpers/projects_helper.rb:205`), `render_descendants_tree` (`issues_helper.rb:145`),
    `render_issue_relations` (`issues_helper.rb:248`) — the project list shares the helper, so a
    change there is not confined to issues.
  - `IssuesHelper`, `controllers/index.js`, `controllers/application.js` and the three small
    controllers: no dependents in the graph, because ERB templates and importmap-loaded JavaScript
    produce no edges Graphify can see. Confirmed by reading instead: `_list.html.erb:22` and `:43`
    are the only uses of `grouped_issue_list` and `link_to_context_menu` in `app/views/issues`, and
    `app/javascript/application.js:1` is the only importer of `controllers`.
  - Outside the area's paths and therefore what a later change must check:
    `app/helpers/projects_helper.rb:205`, `app/views/my/blocks/_issues.erb:26`,
    `lib/redmine/export/pdf/issues_pdf_helper.rb:275`/`:393`/`:429`/`:444`/`:534`,
    `app/views/timelog/_list.html.erb:22` and `app/views/users/_list.html.erb:22` (separate
    partials with their own `inline_columns.size + 2` colspans that must NOT be changed).

Source: commit fd79e435f09736e713cc9f0055cabf250e981898 (tree identical to
53abb0a6c4107c996ee4d478e1f50441f6328912)
Graph queries: `god-nodes --top 15 areas/js-controllers`: hubs are all gantt/quote-reply/table-paste,
none in this area's path; `god-nodes --top 15 areas/helpers`: `ApplicationHelper` (124),
`IssuesHelper` (41), `QueriesHelper` (32) top three, all three covered above;
`affected "grouped_issue_list" --depth 2`: no affected nodes;
`affected "column_content" --depth 2`: 2 dependents — `issues_helper.rb:145`, `issues_helper.rb:248`;
`affected "link_to_context_menu" --depth 2`: 2 dependents — `issues_helper.rb:138`,
`issues_helper.rb:239`;
`affected "QueriesHelper" --depth 2`: 5 dependents — `issues_helper.rb:24`, `issues_helper.rb:41`,
`projects_helper.rb:205`, `issues_helper.rb:145`, `issues_helper.rb:248`;
`affected "IssuesHelper" --depth 2`, `affected "app/javascript/controllers/index.js" --depth 2`,
`affected "app/javascript/controllers/application.js" --depth 2`,
`affected "issue_journal_link_controller.js" --depth 2`,
`affected "sticky_issue_header_controller.js" --depth 2`,
`affected "quote_reply_controller.js" --depth 2`: no affected nodes in each case (ERB and
importmap-loaded JS leave no edges);
`path "grouped_issue_list" "column_content"`: no directed path, `--undirected` gives 3 hops
(`grouped_issue_list` <-- `IssuesHelper` --> `render_descendants_tree` --calls[INFERRED]-->
`column_content`), i.e. the partial's own call at `_list.html.erb:41` is invisible to the graph;
`path "grouped_issue_list" "link_to_context_menu"`: no directed path;
`path "app/javascript/controllers/index.js" "app/javascript/controllers/application.js"`: no path in
either direction, so the loading chain was confirmed by reading the two files;
`path "IssuesController" "app/javascript/controllers/index.js"`: no path, as expected across the
HTTP boundary. `app/views/issues`, `config/locales` and `app/assets/stylesheets` have no graph at
all — Graphify parses no ERB, YAML or CSS — so every claim about those files above was confirmed by
reading them.
