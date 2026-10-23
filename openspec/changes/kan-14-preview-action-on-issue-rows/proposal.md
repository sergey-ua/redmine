# Proposal

## Why

Reading an issue from a list today costs a page navigation and a trip back, which loses the
filters, sort, page and scroll position the user had set up. KAN-14 asks for a Preview control on
every issue row that shows the issue's key attributes and its rendered description beside the list,
without leaving the list. The feature must be read-only: previewing must never change an issue,
write a journal entry or send a notification, and the new control must not leak into CSV export,
PDF export, the column picker or saved queries.

## What Changes

- Add a read-only `GET /issues/:id/preview` member route and action on `IssuesController` that
  renders one issue as a layout-less HTML fragment, inheriting issue visibility from the shared
  `find_issue` filter and permission from the blanket `authorize` filter, and registered under the
  existing `:view_issues` permission so no new permission setting appears.
- The fragment carries a header (issue id, subject, an **Open full issue** link, a close control), a
  summary block (project, tracker, status, priority, assignee — **Unassigned** when there is none)
  and the description rendered through the issue page's own `textilizable` pattern, so inline images
  and macros resolve — **No description** when the description is empty.
- Add a third fixed cell to the shared issue list row, outside the query column model: an empty
  header cell and a row cell holding a labelled Preview link. The group-row and block-column
  `colspan` grows by one with it.
- Add a preview panel to the issue list page, positioned as a fixed overlay docked to the right edge
  of the main content area on desktop (the page's right-hand sidebar region is already occupied by
  the filters and saved queries) and as a full-width block below the list on narrow screens, plus one
  small client-side controller that fetches the fragment and swaps it into the panel without
  navigating or re-rendering the list document.
- Suppress the Preview cell where no panel exists, so the My page issue blocks — which render the
  same list partial — are unchanged and no dead control ships.
- Author two new English locale keys (**Unassigned**, **No description**); every other new string
  reuses an existing key. No user-facing literal is hard-coded in a view.
- Add the server-side proof the ticket demands: repeated previews create no journal and no mail and
  change no attribute; the endpoint honours visibility and permission; CSV headers, the available
  column list and a saved query's stored columns are unchanged and PDF export still succeeds.
- Not breaking: no existing route, action, column, export or saved query changes behaviour.

## Capabilities

### New Capabilities

None. Everything this change adds is behaviour of the existing `issues` capability.

### Modified Capabilities

- `issues`: the read-only fragment surface gains the `GET /issues/:id/preview` member route, the
  `find_issue` filter list and the `:view_issues` action map gain `preview`, the layout-less
  partial-render requirement covers it, the no-write requirement covers it, and the locale
  requirement records the two strings that have no existing key. New requirements describe the fixed
  Preview cell on the list row, the fragment's contents, the client-side panel, the no-new-literal
  rule, and a Verification section holding the proof the acceptance criteria demand.

## Impact

- Routes and controller: `config/routes.rb` (`resources :issues ... member`),
  `app/controllers/issues_controller.rb` (`find_issue` filter list, new `preview` action).
- Permissions: `lib/redmine/preparation.rb` (`map.permission :view_issues`).
- Views: new `app/views/issues/_preview.html.erb`; `app/views/issues/_list.html.erb` (third fixed
  cell, two colspans); `app/views/issues/index.html.erb` (panel container);
  `app/views/my/blocks/_issues.erb` (opts out of the new cell).
- Front end and assets: new `app/javascript/controllers/issue_preview_controller.js` (registered by
  filename); `app/assets/stylesheets/application.css` and `responsive.css`.
- Locales: `config/locales/en.yml` gains two keys; other locale files mirror them.
- Tests: `test/functional/issues_controller_test.rb` (new preview tests plus twelve hard-coded
  cell-count and `colspan` literals), `test/integration/routing/issues_test.rb`,
  `test/system/issues_test.rb`; `test/functional/my_controller_test.rb` and
  `test/system/my_page_test.rb` re-run to prove the My page is undisturbed.
- Receives no change by design: `app/models/query.rb`, `app/models/issue_query.rb`,
  `app/helpers/queries_helper.rb`, `lib/redmine/export/pdf/issues_pdf_helper.rb`.

## Traceability

Ticket: KAN-14
Domain: issues
Criteria: all 8 acceptance criteria of KAN-14 — AC1 (panel opens from the project and global lists
with no navigation), AC2 (a labelled Preview control on every row), AC3 (no Preview column in CSV,
PDF, the available column list or a saved query), AC4 (**Unassigned** / **No description**),
AC5 (**Open full issue** navigates), AC6 (id and subject links, checkboxes, context menu and bulk
actions unchanged), AC7 (no issue change, no journal, no notification, proved server-side),
AC8 (new strings live in the locale files)
