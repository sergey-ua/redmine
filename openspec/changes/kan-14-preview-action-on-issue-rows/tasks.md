# Tasks

## 1. The preview endpoint

- [ ] 1.1 Add `get 'preview'` inside the `resources :issues ... member do` block in
      `config/routes.rb` (`:238-243`), next to the `tab` route, and verify `preview_issue_path` exists
      via `bin/rails routes -g preview`
- [ ] 1.2 Add `:preview` to `before_action :find_issue, :only => [...]` in
      `app/controllers/issues_controller.rb:23` and verify a request for an issue the user may not see
      is refused rather than rendered
- [ ] 1.3 Add `:preview` to the `:issues` action list of `map.permission :view_issues` in
      `lib/redmine/preparation.rb:58` and verify a permitted user gets 200 where, without the entry,
      everyone including an administrator is denied
- [ ] 1.4 Add `IssuesController#preview` after `issue_tab` (`:271`) as a single
      `render :partial => 'issues/preview'` — no `respond_to`, no XHR gate, no entry in
      `accept_api_auth` (`:29`), no call that writes — and verify a plain non-XHR
      `GET /issues/1/preview` returns the bare fragment with no layout
- [ ] 1.5 Add the route assertion for `GET /issues/:id/preview` to
      `test/integration/routing/issues_test.rb`, matching the `issue_tab` precedent at `:39`, and
      verify it passes
- [ ] 1.6 Add `IssuesControllerTest` tests for visibility and permission — anonymous gets a login
      redirect, a logged-in user without permission gets 403, an unknown id gets 404 — and verify they
      pass

## 2. The preview fragment

- [ ] 2.1 Create `app/views/issues/_preview.html.erb` with the header (issue id, subject, an
      **Open full issue** link to `issue_path(@issue)`, a close control), the summary block (project,
      tracker, status, priority, assignee) and the description rendered with
      `textilizable @issue, :description, :attachments => @issue.attachments` (the call at
      `app/views/issues/show.html.erb:119`), and verify the fragment renders for a fixture issue with
      an attachment-image description
- [ ] 2.2 Render **Unassigned** when the issue has no assignee and **No description** when the
      description is blank, both from locale keys, and verify with `IssuesControllerTest` tests on
      fixture issue 1 (no assignee) and issue 11 or 12 (neither)
- [ ] 2.3 Add an `IssuesControllerTest` test asserting the fragment contains the issue id, subject,
      project, tracker, status, priority, assignee and rendered description, with `assert_select`, and
      verify it passes
- [ ] 2.4 Add the `IssuesControllerTest` read-only test: request `preview` for the same issue several
      times inside `assert_no_difference 'Journal.count'`, with `ActionMailer::Base.deliveries`
      cleared before and asserted empty after, and the issue's attributes compared after `reload`;
      verify it passes

## 3. Locale keys

- [ ] 3.1 Add one key whose value is `Unassigned` and one whose value is `No description` to
      `config/locales/en.yml`, in the right key family and alphabetical position, and verify
      `bin/rails test test/unit/lib/redmine/i18n_test.rb` still passes
- [ ] 3.2 Confirm every other string the control, panel and fragment show reuses an existing key
      (`label_preview` `:902`, `button_close` `:1272`, `field_description` `:290`,
      `field_assigned_to` `:323`, `label_issue` `:654`) and verify no literal user-facing text remains
      in the new or edited templates by grepping them

## 4. The fixed Preview cell on the list row

- [ ] 4.1 Add an **empty** `<th class="preview hide-when-print"></th>` after `th.buttons`
      (`app/views/issues/_list.html.erb:18`), rendered only when the page asks for the cell, and
      verify the four `columns_in_issues_list` assertions
      (`test/functional/issues_controller_test.rb:1488`, `:1504`, `:1517`, `:1533`) still pass — an
      empty header is dropped by `select(&:present?)` at `test/test_helper.rb:403`, a captioned one
      is not
- [ ] 4.2 Add `<td class="preview hide-when-print">` after `td.buttons` (`:43`) holding
      `link_to l(:label_preview), preview_issue_path(issue)` with the Stimulus `data-action` — an
      `<a>`, never a `<button>` or `<span>`, because `context_menu.js:32` only ignores anchors — and
      verify a `IssuesControllerTest` assertion that every row has exactly one `td.preview a`
- [ ] 4.3 Change both colspans from `query.inline_columns.size + 2` to `+ 3` together (`:26` and
      `:48`) when the cell is rendered, and verify grouped and block-column rows still span the whole
      table in the functional tests
- [ ] 4.4 Gate the cell and the colspan on a `query_options` flag that
      `app/views/issues/index.html.erb:33` passes and `app/views/my/blocks/_issues.erb:26` does not,
      and verify `bin/rails test test/functional/my_controller_test.rb` passes unchanged (`:56`,
      `:71-90`)
- [ ] 4.5 Update the twelve hard-coded literals in `test/functional/issues_controller_test.rb` —
      `columns.size + 2` → `+ 3` at `:1462`; `thead th, 4` → `5` at `:1758` and `:1783`;
      `colspan="4"` → `"5"` at `:1759`, `:1785`, `:1787`, `:1824`, `:1835`, `:1847`, `:1848`,
      `:1869` — and verify the full `IssuesControllerTest` run is green
- [ ] 4.6 Re-run `test/system/my_page_test.rb` (`:31-79`) and the issue-page subtask/related-issue
      coverage that exercises `render_descendants_tree`
      (`app/helpers/issues_helper.rb:145`) and `render_issue_relations` (`:248`), and verify no
      Preview cell leaked into those tables
- [ ] 4.7 Confirm `app/views/timelog/_list.html.erb:22` and `app/views/users/_list.html.erb:22` keep
      their own `inline_columns.size + 2` colspans unchanged, and verify by `git diff --stat` that
      neither file is touched

## 5. The panel and the client-side controller

- [ ] 5.1 Add the panel container with `data-controller="issue-preview"` and its content target to
      `app/views/issues/index.html.erb`, hidden by default, and verify it is present on both the
      project and the global list and absent from the My page
- [ ] 5.2 Create `app/javascript/controllers/issue_preview_controller.js` following the house shape
      (GPL header, `Controller` from `@hotwired/stimulus"`, `static targets`, `static values`,
      `get` from `@rails/request.js`) that fetches the fragment, swaps it into the target's
      `innerHTML` and shows the panel, plus a method that hides it; verify it is registered by
      filename with no edit to `app/javascript/controllers/index.js`
- [ ] 5.3 Add the panel's desktop placement to `app/assets/stylesheets/application.css` as a
      fixed-position overlay docked to the inline end of `#content`, with `td.preview` sizing beside
      `td.buttons` (`:581`), and verify `npx stylelint "app/assets/stylesheets/**/*.css"` passes
- [ ] 5.4 Add the narrow-screen rule to `app/assets/stylesheets/responsive.css` inside the
      `max-width: 899px` block (issues-page rules from `:731`) so the panel is a full-width block
      below the list, and verify at a 600px and an 1100px viewport in the browser suite
- [ ] 5.5 Add `IssuesSystemTest` tests — click Preview and the panel populates while
      `assert_current_path '/issues', :ignore_query => true` holds; clicking Preview on a second row
      replaces the contents; the close control hides the panel; **Open full issue** navigates to the
      issue page — with names that do not collide with `test_preview_issue_description` (`:242`) or
      `test_update_journal_notes_with_preview` (`:599`); verify they pass
- [ ] 5.6 Add an `IssuesSystemTest` assertion that clicking Preview does not select the row, and that
      the row checkbox, the id link, the subject link and the right-click context menu still behave
      as before; verify it passes

## 6. Proving Preview stays out of exports, the picker and saved queries

- [ ] 6.1 Add an `IssuesControllerTest` CSV assertion inside
      `with_settings :default_language => 'en'` that the header row count is unchanged and
      `assert_not_include 'Preview', headers`; verify it passes
- [ ] 6.2 Add an assertion that the column-selection UI offers no Preview option
      (`option[value=preview]` count 0) and that a loaded saved query's
      `session[:issue_query][:column_names]` is unchanged; verify both pass
- [ ] 6.3 Add an assertion that PDF export of an issue list still succeeds (media type and `%PDF`
      prefix — the only PDF assertions this suite supports); verify it passes
- [ ] 6.4 Verify by `git diff --name-only` that `app/models/query.rb`, `app/models/issue_query.rb`,
      `app/helpers/queries_helper.rb` and `lib/redmine/export/pdf/issues_pdf_helper.rb` are absent
      from the diff; if any appears, stop and report that Preview was implemented as a `QueryColumn`
      rather than editing those files

## 7. Integration check

- [ ] 7.1 Run `bin/rails test test/functional/issues_controller_test.rb`,
      `test/integration/routing/issues_test.rb` and `test/functional/my_controller_test.rb` and verify
      all three are green; record any failure that also reproduces on `master` rather than fixing it
- [ ] 7.2 Run `test/system/issues_test.rb` and `test/system/my_page_test.rb` and verify both are
      green, with the same pre-existing-failure rule
- [ ] 7.3 Run `bundle exec rubocop --parallel` and `npx stylelint
      "app/assets/stylesheets/**/*.css"` and verify both are clean for the files this change touches
- [ ] 7.4 Walk the eight acceptance criteria of KAN-14 against the running app (project list and
      global list) and verify each is observable
