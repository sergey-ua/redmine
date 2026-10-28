# issues-helpers Specification

## Purpose
View helpers used when rendering issues and issue lists: row iteration order, issue links, and issue-related tooltip/relation rendering. `IssuesHelper` mixes in `ApplicationHelper` and several other helpers rather than duplicating their logic.

## Requirements

### Requirement: `IssuesHelper` composes `ApplicationHelper` and sibling helpers instead of duplicating logic
The system SHALL define `IssuesHelper` (app/helpers/issues_helper.rb:20) as a module that `include`s `ApplicationHelper`, `Redmine::Export::PDF::IssuesPdfHelper`, `IssueStatusesHelper`, `QueriesHelper`, and `ReactionsHelper` (lines 21-25), so issue-link rendering (`link_to_issue`) and page-wide asset helpers (`javascript_heads`) live in `ApplicationHelper`, not in `IssuesHelper` itself.

#### Scenario: Looking up a helper method used by issue views
- **WHEN** a view calls a method like `link_to_issue` or `javascript_heads` while rendering an issue list
- **THEN** the method is found in `ApplicationHelper` (app/helpers/application_helper.rb), reachable from `IssuesHelper` through the `include` chain, not defined a second time in `issues_helper.rb`

### Requirement: `issue_list`/`grouped_issue_list` iterate issues while tracking ancestor nesting depth
The system SHALL expose `IssuesHelper#issue_list(issues, &block)` (app/helpers/issues_helper.rb:27) and `#grouped_issue_list(issues, query, &block)` (line 39), both of which maintain an `ancestors` stack and yield `(issue, level, ...)` to the caller so the view can indent descendant rows. `_list.html.erb` calls `grouped_issue_list`.

#### Scenario: A list contains a parent issue followed by its children
- **WHEN** `grouped_issue_list` yields rows for a parent then its children
- **THEN** each child is yielded with `level > 0`, which `_list.html.erb` uses to add an `idnt idnt-#{level}` CSS class to indent the row

### Requirement: `link_to_issue` is the single place that builds a navigable issue link
The system SHALL build every issue hyperlink (ID/subject links in lists, tooltips, relations) through `ApplicationHelper#link_to_issue(issue, options={})` (app/helpers/application_helper.rb:117), which renders `link_to(text, issue_url(issue, only_path: ...), class: issue.css_classes, title: title)` and optionally prefixes the project name or suppresses the subject/tracker per `options`.

#### Scenario: A new UI element needs to link to the full issue page
- **WHEN** new UI (e.g. a side panel's "Open full issue" link) needs the issue's canonical URL
- **THEN** it SHOULD reuse `issue_url(issue)` the same way `link_to_issue` does, rather than constructing the path differently, so the link stays consistent with every other issue link in the application

### Requirement: Description rendering goes through `textilizable`, not a dedicated helper
The system SHALL render an issue's description the same way `show.html.erb` does: `textilizable @issue, :description, :attachments => @issue.attachments` (app/views/issues/show.html.erb:119), guarded by `@issue.description?` — `textilizable` is defined in `ApplicationHelper`, not `IssuesHelper`; there is no separate "description_content" helper in this codebase.

#### Scenario: Issue has no description
- **WHEN** `@issue.description?` is false (description blank)
- **THEN** `show.html.erb` renders no description block at all (the `<% if @issue.description? %>` guard skips it); there is no helper or locale string producing a "No description" placeholder today — this text does not exist in `config/locales/en.yml` and must be newly introduced if a ticket requires it.

### Requirement: Summary field rows use `issue_fields_rows`
The system SHALL build the left/right summary rows on the full issue page (status, priority, assignee, category, fixed_version, dates, done_ratio, estimated_hours) via the `issue_fields_rows` helper block used in `show.html.erb:71-104`, each row guarded by `@issue.disabled_core_fields.include?(...)`.

#### Scenario: No assignee
- **WHEN** `@issue.assigned_to` is nil and `assigned_to_id` is not disabled
- **THEN** `show.html.erb` renders `"-"` (a literal dash) as the assignee value, not a localized "Unassigned" string — that string does not exist in `config/locales/en.yml` either and must be newly introduced if a ticket requires it.

### Requirement: `filename_for_export` builds the download filename shared by every export format; the format extension is appended by the caller
The system SHALL expose `QueriesHelper#filename_for_export(query, default_name)` (app/helpers/queries_helper.rb:343-348): it takes `params[:query_name]` if present, else `query.name`, falls back to `default_name` if that is blank or `'_'`, then runs it through `Wiki.titleize(...).downcase` and `filename_for_content_disposition`. It returns the base filename only (no extension) — every caller appends its own extension, e.g. `"#{filename_for_export(@query, 'issues')}.csv"` and `"#{filename_for_export(@query, 'issues')}.pdf"` in `IssuesController#index` (issues_controller.rb:84, 88). A new export format follows the same pattern: call `filename_for_export` once and append its own extension; the helper itself has no notion of format.

#### Scenario: No query name given
- **WHEN** `params[:query_name]` is absent and the query is unsaved (`query.name` blank)
- **THEN** `filename_for_export(@query, 'issues')` returns `"issues"` (the `default_name` argument, titleized/downcased), confirmed by `test_index_csv_filename_without_query_name_param` asserting `/issues.csv/` in `Content-Disposition`

#### Scenario: A query name is given
- **WHEN** `params[:query_name]` is `'My Query Name'`
- **THEN** the filename becomes `my_query_name` before the caller's extension is appended, confirmed by `test_index_csv_filename_with_query_name_param` asserting `/my_query_name\.csv/`

#### Scenario: The xlsx export format calls the same filename helper
- **WHEN** `IssuesController#index` responds to `format.xlsx` and builds the download filename for the issue list export
- **THEN** it calls `filename_for_export(@query, 'issues')` the same way `format.csv` and `format.pdf` do, and appends `.xlsx` itself (`"#{filename_for_export(@query, 'issues')}.xlsx"`); `filename_for_export` requires no code change to support this third caller

### Requirement: `query_to_csv` is CSV-specific and not reusable as-is for another export format
The system SHALL build the CSV body in `QueriesHelper#query_to_csv(items, query, options={})` (app/helpers/queries_helper.rb:330-341) by iterating `query.columns`, writing a header row of `column.caption`, then one row per item via `csv_content(c, item)` into a `Redmine::Export::CSV.generate` block. This method is CSV-format-specific (it returns CSV text through `csv <<`); a new export format does not call into it and instead builds its own output from `query.columns`/`csv_content`-equivalent value extraction, or iterates `items` directly for a fixed column set.

#### Scenario: A new export format needs issue field values
- **WHEN** a new export format (not CSV, not PDF) needs the same per-issue field values CSV exports (ID, subject, tracker, status, etc.)
- **THEN** it reads those values directly off the `Issue` records (e.g. `issue.id`, `issue.subject`, `issue.tracker`, `issue.status`) or via `csv_content(column, item)` (queries_helper.rb) for values that need `query.columns`-driven formatting, rather than depending on `query_to_csv`'s CSV-shaped return value

## Code map
- app/helpers/issues_helper.rb: `IssuesHelper` module (L20), `issue_list` (L27), `grouped_issue_list` (L39), `issue_fields_rows` (used by show.html.erb); include chain at L21-25.
- app/helpers/application_helper.rb: `link_to_issue` (L117), `link_to_context_menu` (L1634), `javascript_heads` (L1826) — all reachable from `IssuesHelper` via `include ApplicationHelper`.
- app/helpers/queries_helper.rb: `QueriesHelper` module (`include ApplicationHelper`, L22); `query_to_csv` (L330-341, CSV-specific body builder); `filename_for_export` (L343-348, format-agnostic base filename).
- lib/redmine/i18n.rb: `format_time(time, include_date=true, user=nil)` (L81-89) — converts `time` to `user`'s (default `User.current`) timezone via `convert_time_to_user_timezone`, then formats with `Setting.time_format`/`Setting.date_format` through `I18n.l`; returns a locale- and timezone-aware string, date+time by default.
- Entry points: `IssuesHelper` (app/helpers/issues_helper.rb:20), `.link_to_issue()` (app/helpers/application_helper.rb:117), `.filename_for_export()` (app/helpers/queries_helper.rb:343), `.query_to_csv()` (app/helpers/queries_helper.rb:330).
- Depends on this area: `.issue_list()` is used by `.render_descendants_tree()` (issues_helper.rb:116); `.link_to_issue()` is used throughout issues_helper.rb (render_issue_tooltip, render_issue_relations, render_issue_subject_with_tree, show_detail, details_to_strings) and by queries_helper.rb/timelog_helper.rb/custom_fields_helper.rb/roles_helper.rb for value formatting — none of these are inside app/views/issues, so changing either method's signature requires checking those call sites. `.filename_for_export()` and `.query_to_csv()` have no dependents found by the graph within depth 2 (only called from `IssuesController#index`, a cross-area call the graph does not resolve — confirmed by reading issues_controller.rb:84/88 directly).
- `issue_url(issue)` (route helper from `resources :issues`, config/routes.rb:238) generates a path by default in a view (relative, via `url_for`'s view context); in a non-view context such as a generated file's content (not rendered through the normal ERB response), getting a full URL requires either `issue_url(issue, :only_path => false)` or `default_url_options` (`:host`, from `Setting.host_name`/`protocol`) being set — the same mechanism `link_to_issue` already passes `:only_path => only_path` through (app/helpers/application_helper.rb:132), so a new export format wanting a full URL (not a relative path) in a hyperlink must pass `:only_path => false` explicitly rather than relying on the view's default.

Source: commit 53abb0a6c4107c996ee4d478e1f50441f6328912
Graph queries: god-nodes --top 15 --graph areas/helpers/graph.json: IssuesHelper (41 edges) is the area's issue-specific hub, ApplicationHelper (124 edges) is the generic base every helper mixes in; explain IssuesHelper --graph graph.json: found at app/helpers/issues_helper.rb:20, 41 connections; affected ".issue_list()" --depth 2: 1 dependent, `.render_descendants_tree()` (issues_helper.rb:116); affected "issue_list" (bare name, no node-type prefix) --graph graph.json: no unique match (ambiguous/not resolved by bare identifier — confirmed instead with the `.issue_list()` method-node form above); affected ".link_to_issue()" --depth 2: dependents listed in issues_helper.rb, queries_helper.rb, timelog_helper.rb, custom_fields_helper.rb, roles_helper.rb (see Code map); affected IssuesHelper --depth 2 (whole-module node, not a specific method): no affected nodes found — nothing in the graph calls into the module node within depth 2, consistent with it being reached only from ERB views (an edge type Graphify does not extract); affected ".filename_for_export()" --depth 2 --graph /workspace/knowledge/graph/redmine/graph.json: no affected nodes found (only called from issues_controller.rb, a cross-area call the graph does not resolve — confirmed by reading instead); affected ".query_to_csv()" --depth 2: no affected nodes found, same reason; path "IssuesController" ".filename_for_export()" (directed): no path found — confirmed the controller-to-helper call by reading issues_controller.rb:84/88 instead.
