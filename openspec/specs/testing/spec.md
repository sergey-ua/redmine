# testing Specification

## Purpose
This area is the automated proof that issue-list behaviour is what it claims to be, and in
particular that a read-only feature on the issue list writes nothing and never enters the query
column model. Two suites carry it: `test/functional/issues_controller_test.rb`
(`IssuesControllerTest`, a Minitest `ActionController::TestCase` of about 9,400 lines, the dominant
hub of `test/functional` with 486 graph edges) asserts HTTP responses, rendered markup, CSV and PDF
exports and permission outcomes for every `IssuesController` action; and
`test/system/issues_test.rb` (`IssuesSystemTest`, a Capybara/Selenium test, the top hub of
`test/system`) asserts browser behaviour of the issue form and the issue list. Both load all
fixtures in a transaction and run with frozen time. The query column model
(`app/models/query.rb`, `app/models/issue_query.rb`) and the export helpers
(`app/helpers/queries_helper.rb`, `lib/redmine/export/pdf/issues_pdf_helper.rb`) are deliberately
outside what this area changes: they are the mechanism the tests observe, not the subject of a
change.

## Requirements

### Requirement: Controller tests are bound to a controller by class name
The system SHALL infer the controller under test from the test class name, so a test for an action
belongs in the suite named after the controller that owns the action.

#### Scenario: IssuesControllerTest drives IssuesController
- **WHEN** a test in `IssuesControllerTest` issues a bare `get :some_action`
- **THEN** `ActionController::TestCase` resolves the controller by stripping the `Test` suffix from
  the class name, giving `IssuesController`; `test/functional/issues_controller_test.rb` declares no
  `tests` call and no `self.controller_class` override, and `Redmine::ControllerTest`
  (`test/test_helper.rb:395`) adds only helper methods and does not set `@controller`
- **AND** a request for an action that does not exist on `IssuesController` therefore cannot be
  tested from this class; it would need its own `*ControllerTest` or an explicit `tests` declaration.

#### Scenario: Graph shows no static edge from suite to controller
- **WHEN** the dependency graph is asked how the suite reaches the controller
- **THEN** `path "IssuesControllerTest" "IssuesController"` reports no path, in either direction,
  and the same for `IssuesSystemTest` — the binding is made by the Rails test harness at runtime, so
  no static analysis will show which controller a suite exercises.

### Requirement: Every test starts anonymous and logs in per test
The system SHALL reset the acting user before each controller test and require each test to
establish its own identity.

#### Scenario: setup clears the current user
- **WHEN** any test in `IssuesControllerTest` begins
- **THEN** `setup` sets `User.current = nil`
  (`test/functional/issues_controller_test.rb:26-28`) and does not call `super`, so the default
  state of every test is an anonymous request
- **AND** a test that needs a logged-in user sets `@request.session[:user_id] = N` itself.

#### Scenario: System tests log in through the real login form
- **WHEN** a test in `IssuesSystemTest` needs a user
- **THEN** it calls `log_user('jsmith', 'jsmith')`
  (`test/application_system_test_case.rb:75-84`), which visits `/my/page`, fills the login form and
  asserts the landing page.

### Requirement: Fixtures and frozen time constrain what a test may observe
The system SHALL load all fixtures in a transaction and freeze the clock for the whole run.

#### Scenario: All fixtures, transactional, single worker
- **WHEN** the suite boots
- **THEN** `test/test_helper.rb:58` declares `fixtures :all`, `:60` sets
  `use_transactional_tests = true`, `:61` sets `use_instantiated_fixtures = false` and `:54` sets
  `parallelize(workers: 1)`.

#### Scenario: Time is frozen, so timestamp drift is not observable
- **WHEN** a test wants to prove a record was not written
- **THEN** it cannot rely on `updated_on` staying put, because `before_setup` calls
  `travel_to FROZEN_TIME` (`test/test_helper.rb:65-69`) and the clock does not advance during a test
- **AND** the proof must instead compare attribute values explicitly after `reload`.

#### Scenario: Fixtures with no assignee and with an empty description
- **WHEN** a test needs an issue whose assignee or description is absent
- **THEN** issue 1 has `description: Unable to print recipes` and an empty `assigned_to_id`
  (`test/fixtures/issues.yml:11`, `:13`), and issues 11 and 12 have both `description:` and
  `assigned_to_id:` empty (`test/fixtures/issues.yml:207`, `:209`, `:227`, `:229`); issue 11 is
  `Closed issue on a closed version` in project 1
- **AND** issue 14 is the private-issue fixture, and issues 4 and 6 are the ones not visible to
  anonymous users (asserted at `test/functional/issues_controller_test.rb:38-39`).

#### Scenario: System tests run with default settings only
- **WHEN** a system test depends on a `Setting`
- **THEN** it must wrap the request in `with_settings`, because the base class `setup` calls
  `Setting.delete_all` and `Setting.clear_cache`
  (`test/application_system_test_case.rb:65-66`) and the same again in `teardown` (`:69-71`); see
  `test_issue_list_with_default_totalable_columns` (`test/system/issues_test.rb:579-597`) for the
  pattern.

### Requirement: No-writes is proved by three established assertions
The system SHALL prove that a request wrote nothing by asserting no new record, no mail and no
attribute change, using the idioms already in the suite.

#### Scenario: No journal entry is created
- **WHEN** a test must show a request created no journal
- **THEN** it wraps the request in `assert_no_difference 'Journal.count' do ... end`
  (`test/functional/issues_controller_test.rb:4461`, `:5326`, and the permission-negative
  `test_put_update_should_check_add_issue_notes_permission` at `:7255-7270`)
- **AND** the same form covers other tables: `'Issue.count'` (`:4763`, `:5868`),
  `'Attachment.count'` (`:5435`), `'IssueRelation.count'` (`:5998`), `'TimeEntry.count'` (`:6850`)
- **AND** every occurrence in this file passes a single string, never the array form, so stacking
  several counts is done by nesting blocks (`:5325-5326`, `:7224-7225`).

#### Scenario: No notification mail is sent
- **WHEN** a test must show a request sent no mail
- **THEN** it clears the mailbox before the request (`ActionMailer::Base.deliveries.clear`,
  `test/functional/issues_controller_test.rb:4919`, `:5211`, `:5361`) and then asserts
  `ActionMailer::Base.deliveries.empty?` (`:7263`); the counting form
  `assert_equal 3, ActionMailer::Base.deliveries.size` (`:4947`) is used for the positive case
- **AND** clearing first is required rather than optional: `test/test_helper.rb` installs no hook
  that resets `deliveries` between tests.

#### Scenario: The issue's attributes are unchanged
- **WHEN** a test must show a request did not modify an issue
- **THEN** it reloads and compares explicit values, as in `assert_equal 1, Issue.find(1).status_id`
  (`test/functional/issues_controller_test.rb:5565`, `:5635`) and
  `assert_equal 'Original subject', issue.reload.subject` (`:7474`); there is no
  `assert_no_difference` on a timestamp anywhere in this file, which is consistent with time being
  frozen.

### Requirement: Rendered markup is asserted with assert_select, including absence
The system SHALL assert markup contents and the absence of markup with `assert_select`.

#### Scenario: Asserting an element is present with specific text or attributes
- **WHEN** a test checks a rendered issue
- **THEN** it uses `assert_select 'div.issue div.description', :text => /Unable to print recipes/`
  (`test/functional/issues_controller_test.rb:2274`), `assert_select 'a[href=?]', '/issues/1'`
  (`:36`), or a nested block scoped to a container (`:2275-2290`).

#### Scenario: Asserting an element is absent
- **WHEN** a test must show something is not rendered
- **THEN** it passes an explicit count of zero, as in
  `assert_select 'a', {:count => 0, :text => 'Edit'}`
  (`test/functional/issues_controller_test.rb:2278-2283`) and
  `assert_select 'option[value=project]', 0` (`:1478`).

#### Scenario: Fragment responses are asserted without a layout
- **WHEN** the action under test renders a partial rather than a page, as `issue_tab` does
- **THEN** the test asserts directly on the fragment markup with no page wrapper
  (`test/functional/issues_controller_test.rb:3423-3427`, `:3443-3460`).

#### Scenario: Helpers for reading the issue table
- **WHEN** a test needs the rows or the column headers of a rendered issue table
- **THEN** `test/test_helper.rb` provides `issues_in_list` (`:397`), `columns_in_issues_list`
  (`:402`, `css_select('table.issues thead th:not(.checkbox)')`), `columns_in_list` (`:407`) and
  `columns_values_in_list` (`:412`)
- **AND** `test_index_with_columns` counts header cells as `columns.size + 2`
  (`test/functional/issues_controller_test.rb:1449-1479`), the `+ 2` being the two fixed cells the
  list partial contributes outside the column model.

### Requirement: An invisible or unpermitted issue is not reachable, and the status depends on login state
The system SHALL deny access to an issue the acting user cannot see, with a redirect for anonymous
users and 403 for logged-in users, and 404 for an unknown id.

#### Scenario: Anonymous user is redirected
- **WHEN** an anonymous request asks for an issue it may not see
- **THEN** the response is a redirect to login:
  `test_show_should_deny_anonymous_access_without_permission`
  (`test/functional/issues_controller_test.rb:2492`) and
  `test_show_should_deny_anonymous_access_to_private_issue` (`:2498`) both assert
  `assert_response :redirect`.

#### Scenario: Logged-in user without permission gets 403
- **WHEN** a logged-in non-member, or a member whose role lacks `:view_issues`, asks for the issue
- **THEN** the response is `:forbidden`:
  `test_show_should_deny_non_member_access_without_permission` (`:2504`),
  `..._to_private_issue` (`:2511`), `test_show_should_deny_member_access_without_permission`
  (`:2518`, which calls `Role.find(1).remove_permission!(:view_issues)`) and
  `..._to_private_issue_without_permission` (`:2525`)
- **AND** the author and the assignee of a private issue still succeed (`:2532`, `:2539`).

#### Scenario: Unknown id is 404
- **WHEN** the id does not exist
- **THEN** `test_show_invalid_should_respond_with_404`
  (`test/functional/issues_controller_test.rb:3325`) asserts `assert_response :not_found`.

#### Scenario: What produces these outcomes, and the permission map a new action must join
- **WHEN** a member action of `IssuesController` is requested
- **THEN** `before_action :find_issue` (`app/controllers/issues_controller.rb:23`) applies issue
  visibility scoping and `before_action :authorize, :except => [:index, :new, :create]` (`:25`)
  enforces the permission; `find_issue` and `deny_access`
  (`app/controllers/application_controller.rb:340-342`, `:418-429`) are what make the outcome a
  redirect for anonymous users and 403 for logged-in ones
- **AND** `authorize` resolves against the permission map, where `:view_issues` currently lists
  `{:issues => [:index, :show, :issue_tab], ...}` (`lib/redmine/preparation.rb:58`), so an action
  absent from that list is denied even to a user who holds `:view_issues`.

### Requirement: Preview cannot reach CSV, PDF or the column picker when it is fixed markup
The system SHALL feed CSV export, PDF export, the column picker and the persisted column set
exclusively from the query's column list, so markup the list partial contributes directly is
unreachable from any of them.

#### Scenario: Only a QueryColumn can become available
- **WHEN** code tries to add a column to a query
- **THEN** `Query` declares `class_attribute :available_columns` (`app/models/query.rb:351`) with
  `self.available_columns = []` (`:352`) — it is not a method, so only subclasses define
  `def available_columns`, as `IssueQuery` does at `app/models/issue_query.rb:302`
- **AND** the only entry point, `Query.add_available_column` (`app/models/query.rb:804-806`),
  appends solely `if column.is_a?(QueryColumn)`, so nothing that is not a `QueryColumn` can enter
  the list.

#### Scenario: A requested column name that is not available is silently dropped
- **WHEN** a request asks for a column by name, for example `?c[]=preview`
- **THEN** `Query#columns` (`app/models/query.rb:820-827`) resolves each name with
  `available_columns.find {|col| col.name == name}`, so an unknown name yields nothing;
  `inline_columns` (`:829`) and `block_columns` (`:833`) are both derived from `columns`.

#### Scenario: CSV is built only from the query's columns
- **WHEN** an issue list is exported as CSV
- **THEN** `QueriesHelper#query_to_csv` (`app/helpers/queries_helper.rb:330-341`) takes
  `columns = query.columns`, writes the header as `columns.map {|c| c.caption.to_s}` and each row as
  `columns.map {|c| csv_content(c, item)}`; `csv_content` (`:295`) only ever receives a column
  object, confirmed by `path "query_to_csv" "csv_content"` → one hop, `calls` [EXTRACTED]
- **AND** there is no other source feeding the CSV body.

#### Scenario: PDF is built only from the query's columns
- **WHEN** an issue list is exported as PDF
- **THEN** `Redmine::Export::PDF::IssuesPdfHelper#issues_to_pdf`
  (`lib/redmine/export/pdf/issues_pdf_helper.rb:254`) computes widths and cells from the query's
  inline and block columns and never reads the HTML view.

#### Scenario: The existing CSV width assertions are themselves a leak detector
- **WHEN** a new available column appears
- **THEN** `test_index_csv` breaks, because it asserts
  `Setting.issue_list_default_columns.size + 2, lines[0].split(',').size`
  (`test/functional/issues_controller_test.rb:823`), and `test_index_csv_with_all_columns` breaks,
  because with `:c => ['all_inline']` it asserts
  `IssueQuery.new.available_inline_columns.size, lines[0].split(',').size` (`:967`)
- **AND** an explicit caption assertion mirrors `test_index_csv_with_description`
  (`:910-926`), which splits the header line and uses `assert_include 'Description', headers` inside
  `with_settings :default_language => 'en'`; the negative form is `assert_not_include`, used once in
  this file at `:316`, and the caption to exclude is `l(:label_preview)`, i.e. `Preview`
  (`config/locales/en.yml:902`), with `l()` available because the class does
  `include Redmine::I18n` (`test/functional/issues_controller_test.rb:23`).

#### Scenario: A CSV header assertion must pin the locale
- **WHEN** a test splits a CSV header line
- **THEN** it must run inside `with_settings :default_language => 'en'`, because the field separator
  and number format are locale-dependent —
  `test_index_csv_should_format_float_custom_fields_with_csv_decimal_separator`
  (`test/functional/issues_controller_test.rb:988-1030`) splits on `;` under `fr` and on `,` under
  `en`.

#### Scenario: PDF content cannot be asserted with the suite's current idioms
- **WHEN** a test wants to show a caption is absent from a PDF
- **THEN** it cannot, with what exists: `test_index_pdf`
  (`test/functional/issues_controller_test.rb:1163-1194`) and the show-as-PDF test (`:3310-3323`)
  assert only `:success`, `assert_equal 'application/pdf', @response.media_type` and
  `@response.body.starts_with?('%PDF')`, and `save_pdf` (`test/test_helper.rb:430`) only writes the
  file out for a human to look at
- **AND** the PDF side of the claim is therefore proved indirectly, through
  `available_inline_columns` and `inline_columns`, plus an assertion that PDF export still succeeds.

#### Scenario: The column picker offers only available columns
- **WHEN** the issue list renders its options form
- **THEN** `render_query_columns_selection` (`app/helpers/queries_helper.rb:140-143`) renders
  `app/views/queries/_columns.html.erb`, whose two selects are `available_columns` with id
  `available_c` (`:7-11`, fed by `query_available_inline_columns_options`,
  `app/helpers/queries_helper.rb:130-133`) and `c[]` with id `selected_c` (fed by
  `query_selected_inline_columns_options`, `:135-138`)
- **AND** the existing assertion idiom on exactly that markup is
  `assert_select 'select[name=?] option', 'c[]' do assert_select 'option', 3;
  assert_select 'option[value=project]', 0 end`
  (`test/functional/issues_controller_test.rb:1474-1478`), so an absence test is an
  `option[value=preview]` count of zero
- **AND** this assertion belongs in `IssuesControllerTest`, because `QueriesControllerTest` checks
  the picker only at the coarse grain of `assert_select 'fieldset#columns'`
  (`test/functional/queries_controller_test.rb:142`, `:165`, zero-count at `:154`) and never
  enumerates options.

#### Scenario: The persisted column set is observable in the session
- **WHEN** a test must show a name did not enter the saved column set
- **THEN** `test_index_with_columns` reads
  `session[:issue_query][:column_names]`
  (`test/functional/issues_controller_test.rb:1468-1473`), and `query_columns_hidden_tags`
  (`app/helpers/queries_helper.rb:81-87`) likewise iterates `query.columns`, so neither can carry a
  name that is not an available column.

#### Scenario: Changing the column model or the export helpers is the signal of a defect
- **WHEN** making the Preview affordance appear requires editing `app/models/query.rb`,
  `app/models/issue_query.rb`, `app/helpers/queries_helper.rb` or
  `lib/redmine/export/pdf/issues_pdf_helper.rb`
- **THEN** the affordance has been implemented as a `QueryColumn` rather than as fixed markup, which
  contradicts the requirement that it stay out of exports and the picker — the correct response is
  to report that, not to adapt those files.

### Requirement: System tests drive the issue list by row and assert that navigation did not happen
The system SHALL exercise the issue list in a real browser and assert the list is still displayed.

#### Scenario: Driver and setup
- **WHEN** a system test runs
- **THEN** `ApplicationSystemTestCase` uses `driven_by :selenium, using: :chrome,
  screen_size: [1024, 900]` (`test/application_system_test_case.rb:39`), overridable through
  `SELENIUM_REMOTE_URL`, `CAPYBARA_APP_HOST` and `GOOGLE_CHROME_OPTS_ARGS` (`:26-50`), and provides
  `wait_for_ajax` (`:91-95`, which polls `jQuery.active`), `sign_out_user` (`:86`),
  `clear_downloaded_files` (`:64`) and `downloaded_file` (`:112`).

#### Scenario: Targeting a row
- **WHEN** a test acts on one issue in the list
- **THEN** it addresses the row by id, as in
  `find('tr#issue-1 input[type=checkbox]').click` and
  `find('tr#issue-1 td.updated_on').right_click`
  (`test/system/issues_test.rb:744-746`), then works `within('#context-menu')` (`:747`).

#### Scenario: Asserting that the page did not navigate
- **WHEN** a test must show an interaction kept the list on screen
- **THEN** it asserts the path is unchanged with
  `assert_current_path '/issues', :ignore_query => true`
  (`test/system/issues_test.rb:462`, `:472`, `:535`, `:762`); the alternative
  `assert_equal issue_path(:id => issue), current_path` (`:45`) is used for the navigating case.

#### Scenario: Asserting presence and absence in the browser
- **WHEN** a test checks a panel appeared or disappeared
- **THEN** presence uses `assert_selector` or `find ..., :visible => true`
  (`test/system/issues_test.rb:729`, `:190`, `:249`) and absence uses
  `assert page.has_no_css?(...)` (`:594`, `:698`) or `assert_no_selector`
  (`:730`, `:191`).

#### Scenario: Existing preview tests are about the textile preview, not the issue list
- **WHEN** naming a new test or choosing a selector for a list-side preview
- **THEN** it must not collide with `test_preview_issue_description`
  (`test/system/issues_test.rb:242-258`), `test_update_journal_notes_with_preview` (`:599-620`) or
  `test_preview_custom_field_on_bulk_edit_across_projects` (`:738-771`), which all exercise the
  wiki/textile preview on the issue *form* through `a.tab-preview`, `div.wiki-preview` and
  `preview_*` element ids
- **AND** `test_preview_issue_description` in fact writes an issue
  (`assert_difference 'Issue.count'`, `:251`), so it is not a precedent for read-only behaviour.

#### Scenario: Animations are disabled when they would make a test flaky
- **WHEN** a test interacts with an element behind a jQuery animation
- **THEN** it disables animation with
  `page.driver.execute_script('$.fx.off = true;')` (`test/system/issues_test.rb:641`).

### Requirement: Only the changed classes are run, and a pre-existing failure is reported, not fixed
The system SHALL run the suites of the changed classes alone.

#### Scenario: Running one class or one test
- **WHEN** the functional suite is run
- **THEN** `bin/rails test test/functional/issues_controller_test.rb` runs the class and
  `-n test_index_csv` or `-n "/preview/"` narrows it to named tests
  (`doc/RUNNING_TESTS:15-16`).

#### Scenario: Running the system suite
- **WHEN** the system suite is run
- **THEN** `bin/rails test:system TEST=test/system/issues_test.rb` runs it; system tests need Chrome
  on `PATH` (`doc/RUNNING_TESTS:70-77`) and are excluded from a plain `bin/rails test`
  (`doc/RUNNING_TESTS:11-12`).

#### Scenario: A test already failing on the target branch
- **WHEN** a test fails and the same failure reproduces on `master`
- **THEN** it is recorded as a pre-existing failure and left alone.

## Code map
- `test/functional/issues_controller_test.rb`: the `IssuesController` suite — responses, rendered
  markup, CSV and PDF exports, permission outcomes; where the no-writes proof for a read-only
  endpoint belongs.
- `test/system/issues_test.rb`: the Capybara suite for the issue form and the issue list; where the
  no-navigation and panel-visibility proofs belong.
- `test/test_helper.rb`: `ActiveSupport::TestCase` configuration (all fixtures, transactional,
  single worker, frozen time) plus `Redmine::ControllerTest` and the issue-table reading helpers.
- `test/application_system_test_case.rb`: Selenium driver, login helper, per-test `Setting` wipe,
  download helpers.
- `test/fixtures/issues.yml`: the issue fixtures, including those with no assignee and no
  description.
- `app/models/query.rb`, `app/models/issue_query.rb`: the column model these tests observe; must not
  change for this ticket.
- `app/helpers/queries_helper.rb`, `lib/redmine/export/pdf/issues_pdf_helper.rb`: the export and
  picker helpers these tests observe; must not change for this ticket.
- `lib/redmine/preparation.rb`: the permission map `authorize` consults; a new member action must be
  listed under `:view_issues` at `:58` to be reachable.
- Entry points: `IssuesControllerTest` (`test/functional/issues_controller_test.rb:22`),
  `IssuesSystemTest` (`test/system/issues_test.rb:22`),
  `Redmine::ControllerTest` (`test/test_helper.rb:395`),
  `ApplicationSystemTestCase` (`test/application_system_test_case.rb:22`),
  `Query.add_available_column` (`app/models/query.rb:804`),
  `Query#columns` (`app/models/query.rb:820`),
  `IssueQuery#available_columns` (`app/models/issue_query.rb:302`),
  `QueriesHelper#query_to_csv` (`app/helpers/queries_helper.rb:330`),
  `Redmine::Export::PDF::IssuesPdfHelper#issues_to_pdf`
  (`lib/redmine/export/pdf/issues_pdf_helper.rb:254`).
- Depends on this area: none outside the area for either suite —
  `affected "IssuesControllerTest" --depth 2` and `affected "IssuesSystemTest" --depth 2` both
  report no affected nodes, which is expected: nothing in the repository imports a test class.
- Depends on the observed boundary, outside the area's test paths:
  `QueriesHelper` is mixed into `IssuesHelper` (`app/helpers/issues_helper.rb:24`) and called from
  `grouped_issue_list` (`app/helpers/issues_helper.rb:41`), `grouped_project_list`
  (`app/helpers/projects_helper.rb:205`), `render_descendants_tree`
  (`app/helpers/issues_helper.rb:145`) and `render_issue_relations`
  (`app/helpers/issues_helper.rb:248`); `column_content` is reached from
  `render_descendants_tree` (`app/helpers/issues_helper.rb:145`) and `render_issue_relations`
  (`app/helpers/issues_helper.rb:248`); `csv_content` is reached only from `query_to_csv`
  (`app/helpers/queries_helper.rb:338`). `column_header`, `query_to_csv`, `issues_to_pdf`,
  `IssueQuery#available_columns`, `Query#inline_columns` and `Query#block_columns` have no
  dependents in the graph, because their only callers are ERB templates, which Graphify does not
  parse.

Source: commit 53abb0a6c4107c996ee4d478e1f50441f6328912
Graph queries: `god-nodes --top 15 areas/tests-functional`: `IssuesControllerTest`
(`test/functional/issues_controller_test.rb:22`, 486 edges) the dominant hub, `QueriesControllerTest`
(67) the only other relevant one, 13 unrelated controller suites dropped;
`god-nodes --top 15 areas/tests-system`: `IssuesSystemTest` (`test/system/issues_test.rb:22`,
29 edges) the top hub, 14 unrelated system suites dropped;
`affected "IssuesControllerTest" --depth 2`: no affected nodes;
`affected "IssuesSystemTest" --depth 2`: no affected nodes;
`affected "QueriesHelper" --depth 2`: 5 dependents, all outside the area's test paths
(`app/helpers/issues_helper.rb:24`, `:41`, `:145`, `:248`, `app/helpers/projects_helper.rb:205`);
`affected "column_content" --depth 2`: 2 dependents
(`app/helpers/issues_helper.rb:145`, `:248`);
`affected "csv_content" --depth 2`: 1 dependent (`app/helpers/queries_helper.rb:338`);
`affected "column_header" --depth 2`, `affected "query_to_csv" --depth 2`,
`affected "issues_to_pdf" --depth 2` (node id
`areas-5::pdf_issues_pdf_helper_redmine_export_pdf_issuespdfhelper_issues_to_pdf`),
`affected "available_columns" --depth 2` (node id
`areas::issue_query_issuequery_available_columns`),
`affected "inline_columns" --depth 2`, `affected "block_columns" --depth 2`: no affected nodes in
each case — their callers are ERB templates and controller actions Graphify does not link;
`path "query_to_csv" "csv_content"`: 1 hop, `calls` [EXTRACTED];
`path "inline_columns" "available_columns"`: no directed path, `--undirected` gives 3 hops
(`inline_columns` <--method-- `Query` <--inherits-- `IssueQuery` --method--> `available_columns`),
which is the inheritance fact the spec relies on;
`path "issues_to_pdf" "inline_columns"` (both directions): no path, so the PDF-to-column-model link
was confirmed by reading `lib/redmine/export/pdf/issues_pdf_helper.rb`;
`path "IssuesControllerTest" "IssuesController"` and
`path "IssuesSystemTest" "IssuesController"` (both `--undirected`): no path — a test suite reaches
its controller through the Rails test harness, not a static edge.
`explain` was run on each identifier the ticket names; `assert_no_difference`,
`Journal.count` and `ActionMailer::Base.deliveries` are not nodes (framework symbols and a call
expression, not repository definitions) and `Query#available_columns` is not a node either, because
it is a `class_attribute` (`app/models/query.rb:351`), not a `def`. `test/fixtures/*.yml`,
`doc/RUNNING_TESTS` and `config/locales/en.yml` have no graph at all — Graphify parses no YAML or
plain text — so every claim about them was confirmed by reading them.
