# Design

## Context

See `proposal.md` — Why. Requirements are in `specs/issues/spec.md`; the current behaviour this
builds on is in `openspec/specs/issues/spec.md`, `openspec/specs/issue-list/spec.md` and
`openspec/specs/testing/spec.md`.

Three constraints shape the approach:

1. `IssuesController` already has a read-only HTML-fragment action, `issue_tab`
   (`app/controllers/issues_controller.rb:257`), reached by a `member` route
   (`config/routes.rb:240`) and gated by `find_issue` (`:23`) plus the blanket `authorize` (`:25`).
   The preview endpoint is a fourth action of exactly that shape.
2. `app/views/issues/_list.html.erb` already renders two cells outside the query column model — a
   leading `td.checkbox` (`:39`) and a trailing `td.buttons` (`:43`) — so a third fixed cell is the
   established way to put a control on a row without touching `Query`.
3. The issue list page has no free right-hand region: `app/views/issues/index.html.erb:84-86` fills
   `content_for :sidebar` with `issues/sidebar` (filters and saved queries).

Three points were decided by a person on the ticket (`Q1 A, Q2 A, Q3 A`, 2026-10-23) and are taken
as given here: overlay placement, no control on the My page, and the ticket's exact wording for the
two new strings.

## Goals / Non-Goals

**Goals:**

- Keep Preview entirely outside the query column model, so acceptance criterion 3 holds by
  construction rather than by test.
- Add the panel without reworking the issue list page's column layout or its breakpoints.
- Keep every existing row interaction — id and subject links, checkbox, right-click context menu,
  bulk actions — byte-for-byte unchanged in behaviour.

**Non-Goals:**

- No preview on any issue table other than the issue list page (subtask tree, related issues, My
  page blocks).
- No caching, prefetching or keyboard navigation for the panel.
- No new permission, no API representation, no change to the existing markup-preview endpoint.

## Decisions

### D1. `preview` is a member action on `IssuesController`, modelled on `issue_tab`

`config/routes.rb` gains `get 'preview'` inside the existing `resources :issues ... member do` block
(`:238-243`), next to `get 'tab/:name', :action => 'issue_tab', :as => 'tab'`. The action is added to
`before_action :find_issue, :only => [...]` (`:23`) — that single list entry is what gives the
endpoint issue visibility — and `:preview` is added to the `:issues` action list of
`map.permission :view_issues` (`lib/redmine/preparation.rb:58`). The action body is one
`render :partial => 'issues/preview'`; no `respond_to`, no entry in `accept_api_auth` (`:29`).

*Alternative rejected:* a new controller (e.g. `IssuePreviewsController`). It would duplicate the
filter wiring and need its own permission-map entry under a new controller key, for no gain.

*Alternative rejected:* copying `issue_tab`'s `request.xhr?` / 422 gate (`:258`). The decision batch
settled this: the endpoint is a side-effect-free GET returning a bare fragment, so the gate is not a
security control, and leaving it off keeps the URL openable for debugging.

### D2. The Preview control is a third fixed cell, and must be an `<a>` with an empty `th`

In `_list.html.erb`: an empty `<th class="preview hide-when-print"></th>` after `th.buttons` (`:18`),
and a `<td class="preview hide-when-print">` after `td.buttons` (`:43`) holding
`link_to l(:label_preview), preview_issue_path(issue)` carrying the Stimulus `data-action`. Both
`colspan` expressions, `query.inline_columns.size + 2` at `:26` and `:48`, become `+ 3`.

Two shapes here are load-bearing and easy to get wrong:

- The header cell MUST stay empty. `columns_in_issues_list` (`test/test_helper.rb:403`) selects
  `table.issues thead th:not(.checkbox)` and then `.select(&:present?)`; an empty `th` is dropped, a
  captioned one is counted as a column and breaks four assertions
  (`test/functional/issues_controller_test.rb:1488`, `:1504`, `:1517`, `:1533`).
- The control MUST be an `<a>`. `contextMenuRightClick` returns early on `a:not(.js-contextmenu)`
  (`app/assets/javascripts/context_menu.js:11`) and `contextMenuClick` returns on any `a` or `img`
  (`:32`). A `<button>` or a `<span>` is not matched by `target.is('a')`, falls through into the
  row-selection branch (`:36-48`) and toggles the row — a direct criterion-6 regression.

*Alternative rejected:* a `QueryColumn`. It would put Preview into CSV, PDF, the column picker and
saved queries, breaking criterion 3. This is the hard constraint below.

### D3. The cell is opt-in via a `query_options` flag, so the My page is untouched

`_list.html.erb` already takes an optional `query_options` hash and defaults it to `{}` (`:1-2`).
`index.html.erb:33` passes the flag that enables the Preview cell; `app/views/my/blocks/_issues.erb:26`
does not, so the My page block renders exactly the markup it renders today — including the `+ 2`
colspans, since the flag also selects the fixed-cell count.

*Alternative rejected:* always rendering the cell. It ships a labelled control on the My page that
opens nothing, because that page has no panel.

*Alternative rejected:* rendering it everywhere and falling back to the full issue page where there
is no panel. The same labelled control would then behave differently on different pages.

### D4. The panel is a fixed-position overlay inside the content area

`index.html.erb` gains a panel container with `data-controller="issue-preview"` and a target element.
On desktop it is `position: fixed`, docked to the inline end of `#content`, hidden until opened —
styled in `app/assets/stylesheets/application.css` next to the layout containers (`:320-378`). At
`max-width: 899px` (`responsive.css:34`, issues-page rules from `:731`) it becomes a full-width block
below the list.

*Alternative rejected:* a genuine third column. `#main` is a `flex-direction: row-reverse` row
(`application.css:320`) with per-breakpoint sidebar widths (`:322-328`); a third column means
reworking every breakpoint and narrowing the list on mid-width screens.

*Alternative rejected:* reusing `#sidebar`. The filters and saved queries would vanish whenever
someone previews an issue.

### D5. One Stimulus controller, registered by filename, using `@rails/request.js`

`app/javascript/controllers/issue_preview_controller.js` is picked up by
`eagerLoadControllersFrom("controllers", application)` (`app/javascript/controllers/index.js:3`) via
`pin_all_from` (`config/importmap.rb:9`), so it needs no edit to `index.js` and is addressed as
`data-controller="issue-preview"`. It follows the house shape of the existing small controllers
(GPL header, `static targets`, `static values`, `data-action` bindings) and fetches with `get` from
`@rails/request.js` — as `searchable_selection_controller.js:8` does — not bare `fetch`. It swaps the
response into the panel target's `innerHTML` and toggles visibility; it never navigates and never
re-renders the list, which is what preserves filters, sort, page and scroll position.

### D6. The fragment reuses the issue page's description-rendering call verbatim

`app/views/issues/_preview.html.erb` renders the description with
`textilizable @issue, :description, :attachments => @issue.attachments`, the exact call at
`app/views/issues/show.html.erb:119`. That is what resolves inline attachment images, wiki links and
macros, and it shares the formatted-text cache key with the issue page. `textilizable` needs no
controller-side setup and does not require `@journals`.

### D7. Two new locale keys, with the ticket's exact words

`config/locales/en.yml` gains one key whose value is `Unassigned` and one whose value is
`No description`. Everything else reuses existing keys: `label_preview` (`:902`), `button_close`
(`:1272`), `field_description` (`:290`), `field_assigned_to` (`:323`), `label_issue` (`:654`).

*Alternative rejected:* reusing `label_none` / `label_nobody`. Their values are lower-case `none` and
`nobody`, so the panel would not read as acceptance criterion 4 specifies and the criterion would
have to be reworded.

### Hard constraint: the column model and the export helpers receive no change

`app/models/query.rb`, `app/models/issue_query.rb`, `app/helpers/queries_helper.rb` and
`lib/redmine/export/pdf/issues_pdf_helper.rb` MUST be unchanged. `Query.available_columns` is a
`class_attribute` (`query.rb:351-352`); only subclasses define `def available_columns`
(`issue_query.rb:302`); `Query.add_available_column` (`:804-806`) appends only
`if column.is_a?(QueryColumn)`. CSV (`queries_helper.rb:330-341`), PDF
(`issues_pdf_helper.rb:254-278`), the column picker and a saved query's `column_names` all iterate
only the query's column list, so template markup cannot reach them. If a change in any of those four
files appears necessary, Preview was implemented as a `QueryColumn` — report it, do not work around
it.

## Also affected

Carried from `/workspace/delivery/KAN-14/exploration-kan-14-preview-action-on-issue-rows.md` §5 (the
dependency graph's answer; not recomputed here), with what happens to each entry.

**Must change** — the new `th` and the `+2` → `+3` colspans break twelve literals, all in
`test/functional/issues_controller_test.rb`. Each is listed because missing one is a silent failure.

| Location | Today | Becomes |
|---|---|---|
| `:1462` | `assert_select 'th', columns.size + 2` | `+ 3` |
| `:1758`, `:1783` | `assert_select 'table.issues thead th', 4` | `5` |
| `:1759`, `:1785`, `:1787`, `:1824`, `:1835`, `:1847`, `:1848`, `:1869` | `colspan="4"` | `"5"` |

**Must be tested:**

- `app/views/my/blocks/_issues.erb:26` — renders the same partial. Under D3 it does not pass the
  flag, so the block is unchanged; `test/functional/my_controller_test.rb:56`, `:71-90` and
  `test/system/my_page_test.rb:31-79` are re-run to prove it. Neither asserts a `th` count or a
  `colspan` today, so neither breaks on the literals above.
- `app/helpers/issues_helper.rb:145` (`render_descendants_tree`) and `:248`
  (`render_issue_relations`) — dependents of `column_content` and `link_to_context_menu`. They render
  their own issue tables with their own markup, not the list partial; re-run to prove the cell did
  not leak into the subtask and related-issue tables on the issue page.
- `test/test_helper.rb:403` `columns_in_issues_list` — survives only because the new `th` is empty
  (D2). The four assertions that depend on it are re-run.
- `app/assets/javascripts/context_menu.js:11`, `:32`, `:36-48` — criterion 6. The `<a>` shape (D2) is
  what keeps the click out of the selection branch; asserted in the browser suite.

**Unaffected** (no action): `app/helpers/queries_helper.rb:243`, `:265` and the other `textilizable`
dependents (`journals_helper.rb:72`, `application_helper.rb:457`, `projects_helper.rb:87`,
`projects_queries_helper.rb:33`) — `textilizable` itself is not modified and the fragment adds no
caller to the helper. `projects_helper.rb:205` (`grouped_project_list`) — a different partial with its
own colspans. `app/views/timelog/_list.html.erb:22` and `app/views/users/_list.html.erb:22` — separate
partials with their own `inline_columns.size + 2`, which MUST NOT be changed. The eleven
`QueryColumn` dependents (`issue_query.rb:319`, `user_query.rb:102`, the subclasses and the
`query.rb` call sites) — unaffected because no `QueryColumn` is created. `authorize`'s two dependents
(`application_controller.rb:365`, `:393`) — `authorize` is not modified; only the `find_issue`
`:only` list in `IssuesController` is. `IssuesController`, `IssuesController#issue_tab`,
`find_issue`, `grouped_issue_list`, `IssuesControllerTest` and `IssuesSystemTest` have no dependents
at all in the graph.

## How the work is tested

Per `openspec/specs/testing/spec.md`: only the changed classes are run
(`bin/rails test test/functional/issues_controller_test.rb` and the two system files), never the whole
suite, and a failure that reproduces on `master` is recorded, not fixed.

- `test/integration/routing/issues_test.rb` — a route assertion for `GET /issues/:id/preview`,
  matching the `issue_tab` precedent at `:39`.
- `test/functional/issues_controller_test.rb` (`IssuesControllerTest`) — fragment contents;
  **Unassigned** on fixture issue 1 (`test/fixtures/issues.yml:13`) and **No description** on issue
  11 or 12 (`:207`, `:209`, `:227`, `:229`); repeated `get :preview` with
  `assert_no_difference 'Journal.count'`, `ActionMailer::Base.deliveries` cleared before and empty
  after, and attribute comparison after `reload` (time is frozen, `test/test_helper.rb:65-69`, so
  `updated_on` drift is not observable); anonymous redirect, logged-in 403, unknown-id 404; CSV header
  count and `assert_not_include 'Preview', headers` inside
  `with_settings :default_language => 'en'`; `option[value=preview]` count 0 in the column picker;
  `session[:issue_query][:column_names]` unchanged; PDF export still `:success`. Plus the twelve
  literals above.
- `test/system/issues_test.rb` (`IssuesSystemTest`) — click Preview, panel populates,
  `assert_current_path '/issues', :ignore_query => true`; close hides it; **Open full issue**
  navigates; row checkbox, id link, subject link and right-click context menu still behave. New test
  names must not collide with the unrelated `test_preview_issue_description` (`:242`) or
  `test_update_journal_notes_with_preview` (`:599`).
- Re-run `test/functional/my_controller_test.rb` and `test/system/my_page_test.rb` for the My-page
  spillover.
- `bundle exec rubocop --parallel` and `npx stylelint "app/assets/stylesheets/**/*.css"` for the
  Ruby and CSS the change adds.

## Risks / Trade-offs

- A captioned `th.preview` → four `columns_in_issues_list` assertions break. Mitigation: D2 keeps the
  header cell empty, exactly as `th.buttons` is.
- A non-`<a>` Preview control → `contextMenuClick` toggles row selection, regressing criterion 6.
  Mitigation: D2 makes it a link; the browser suite asserts the row is not selected after a Preview
  click.
- The two colspans bumped out of step, or one of the twelve test literals missed → group headers and
  block-column rows under-span the table. Mitigation: both colspans are one task, and each literal is
  enumerated in Also affected.
- PDF absence cannot be asserted directly — the suite asserts only the media type and the `%PDF`
  prefix (`test/functional/issues_controller_test.rb:1163-1194`, `save_pdf` at
  `test/test_helper.rb:430`). Mitigation: the claim is proved through the column model plus an
  assertion that export still succeeds; accepted as indirect.
- The overlay covers the rightmost part of the list while open, which a third column would not.
  Accepted: the decision batch chose this over reworking every breakpoint.
- `{{thumbnail}}` keys off `action_name == 'preview'`
  (`lib/redmine/wiki_formatting/macros.rb:342-344`). The branch is inert because the action has no
  `find_attachments` filter and so no `@attachments`. Mitigation: a note to re-check if the action
  ever gains attachments; no code change now.

## Migration Plan

None. Additive only: a new route, a new action in the existing permission map entry, new templates,
one new JS file, two new locale keys and additive CSS. No schema change, no data migration, no change
to any existing saved query. Rollback is reverting the commit.
