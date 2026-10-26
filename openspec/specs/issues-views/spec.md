# issues-views Specification

## Purpose
Renders the issue list (global `/issues` and per-project issue lists) as an HTML table, shared by `index.html.erb` and any other controller action that lists issues. Governs row markup, per-row navigation links, and which assets (JS/CSS) load on the page.

## Requirements

### Requirement: Issue list partial renders one table shared by all list pages
The system SHALL render issue lists through the `issues/_list` partial (app/views/issues/_list.html.erb), which `issues/index.html.erb` invokes with `:locals => {:issues => @issues, :query => @query}` (index.html.erb:27).

#### Scenario: Global and per-project lists share markup
- **WHEN** the global `/issues` list or a project's issue list is rendered
- **THEN** both go through the same `issues/_list` partial, so a change to row markup in that partial affects every issue list in the application

### Requirement: Each row links the issue subject via `link_to_issue`, not a generic path helper
The system SHALL build the per-row ID/subject link through `IssuesHelper#issue_list` (app/helpers/issues_helper.rb:27, a block iterator used by `_list.html.erb`'s `grouped_issue_list` call) and `ApplicationHelper#link_to_issue` (app/helpers/application_helper.rb:117), which renders `link_to(text, issue_url(issue, ...), class: issue.css_classes, title: title)`.

#### Scenario: Row subject links to the full issue page
- **WHEN** a list row is rendered
- **THEN** the ID/subject cell links to `issue_url(issue)` (full issue page), independent of any other per-row action

### Requirement: Row-level controls live in the buttons column, separate from the subject link
The system SHALL render per-row action controls (currently only the context-menu trigger, via `link_to_context_menu`, application_helper.rb:1634) in a dedicated `<td class="buttons hide-when-print">` cell (_list.html.erb:44), distinct from the `<td>` holding `column_content(column, issue)` for the subject/ID column.

#### Scenario: Row has a non-navigation action alongside its subject link
- **WHEN** a row needs an action that is not "go to the issue page" (e.g. opening the context menu)
- **THEN** that control is placed in the buttons `<td>`, so a new per-row action (e.g. a future "Preview" link) can be added to the same cell without disturbing the subject/ID link's navigation behavior

### Requirement: Global page scripts and styles load once per page via `javascript_heads` and the layout's `stylesheet_link_tag`
The system SHALL include page-wide JavaScript through `ApplicationHelper#javascript_heads` (application_helper.rb:1826), called from `app/views/layouts/base.html.erb:13`, which chains `javascript_include_tag('jquery-3.7.1-ui-1.13.3', 'rails-ujs', 'tribute-5.1.3.min')` and `javascript_include_tag('application-legacy', 'responsive')`. Stylesheets load through `stylesheet_link_tag 'jquery/jquery-ui-1.13.2', 'tribute-5.1.3', 'application', 'dropdown', 'responsive'` in base.html.erb:11.

#### Scenario: A new script must be loaded application-wide
- **WHEN** a new per-page script (e.g. for a list feature) needs to run on every page that renders the issue list
- **THEN** it is registered through `javascript_heads` (an additional `javascript_include_tag` call) or bundled via the Propshaft/importmap pipeline (config/importmap.rb), not inlined per-partial

### Requirement: No "preview panel" or side-panel UI exists yet
The system SHALL NOT currently provide any AJAX-loaded preview of an issue from the list view. No `preview_panel` view, partial, or JavaScript file exists in app/views/issues/ or app/assets/javascripts/. The existing `/issues/preview` route (config/routes.rb:41, `previews#issue`) is an unrelated Textile/Markdown text-preview endpoint for the edit form, not an issue-detail preview.

#### Scenario: Looking for prior art before adding Preview
- **WHEN** implementing the ticket's "Preview" row action and side panel
- **THEN** there is no existing panel component to extend; a new partial/JS file is needed, and the new preview endpoint's route must not reuse `preview_issue` (`/issues/preview`)

## Code map
- app/views/issues/_list.html.erb: row markup for grouped/ungrouped issue tables; the `<td class="buttons hide-when-print">` cell (line 44) is where a per-row Preview link belongs.
- app/views/issues/index.html.erb: global issue list page; renders `issues/_list` partial (line 27); per-project lists reuse the same partial through other controller actions.
- app/helpers/issues_helper.rb: `issue_list` (L27) and `grouped_issue_list` (L39) drive row iteration (ancestor/level bookkeeping) that `_list.html.erb` calls.
- app/helpers/application_helper.rb: `link_to_issue` (L117, subject/ID link), `link_to_context_menu` (L1634, per-row buttons-column control), `javascript_heads` (L1826, global per-page script loading).
- app/views/layouts/base.html.erb: calls `javascript_heads` (L13) and `stylesheet_link_tag` (L11), the two places global assets are wired in.
- config/routes.rb:41: existing `preview_issue` route (`previews#issue`), not to be reused for the new preview-panel endpoint.
- Entry points: `issue_list()` (app/helpers/issues_helper.rb:27), `link_to_issue()` (app/helpers/application_helper.rb:117), `javascript_heads()` (app/helpers/application_helper.rb:1826).
- Depends on this area: `.issue_list()` is called by `.render_descendants_tree()` (app/helpers/issues_helper.rb:116) — outside list rendering, so changing `issue_list`'s block signature would also affect descendant-tree rendering. `.link_to_issue()` has callers across issues_helper.rb (tooltip, relations, descendants) and queries_helper/timelog_helper/custom_fields_helper via shared column formatting — a change to its signature is widely felt, but adding a separate row-level Preview link does not touch it.
- app/views/issues (no Graphify graph: ERB is not parsed by this image's graph build); read directly, confirmed above.

Source: commit 53abb0a6c4107c996ee4d478e1f50441f6328912
Graph queries: explain IssuesHelper --graph graph.json: 41 edges, found at app/helpers/issues_helper.rb:20; affected ".issue_list()" --depth 2: 1 dependent, `.render_descendants_tree()` (issues_helper.rb:116), outside list rendering proper; affected ".link_to_issue()" --depth 2: callers in issues_helper.rb (render_descendants_tree, render_issue_relations, render_issue_subject_with_tree, render_issue_tooltip, show_detail, details_to_strings) and in queries_helper.rb/timelog_helper.rb/custom_fields_helper.rb/roles_helper.rb via shared value-formatting methods; explain "preview" --graph graph.json: ambiguous, matches only wiki_controller.rb and messages_controller.rb (unrelated existing `preview` actions), confirming no issue-preview code exists yet; path "IssuesController" ".issue_list()" --undirected: no path found (ERB views are not in the graph, so controller-to-view edges never appear; confirmed by reading the files instead).
