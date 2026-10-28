# Tasks

## 1. Add the caxlsx dependency

- [x] 1.1 Add `gem "caxlsx"` to `Gemfile` and run `bundle install`; verify with
      `bundle exec ruby -e "require 'caxlsx'; puts Axlsx::VERSION"` that it loads.

## 2. Extend the export guard and invalid-query branch

- [x] 2.1 In `app/controllers/issues_controller.rb#index`, extend the guard at line 51 to
      `(request.format.csv? || request.format.pdf? || request.format.xlsx?)`. Verify with a
      functional test: a user without `:export_issues` requesting `format: 'xlsx'` on `index`
      gets a 403 (`deny_access`).
- [x] 2.2 Extend the invalid-query branch's `format.any(:atom, :csv, :pdf)` to
      `format.any(:atom, :csv, :pdf, :xlsx)`. Verify with a functional test: an invalid query
      (e.g. a bad filter) requested as `format: 'xlsx'` returns 422
      (`head :unprocessable_content`), not a 200.

## 3. Build the xlsx workbook in a new `format.xlsx` branch

- [x] 3.1 Add a `format.xlsx do ... end` block to `index`'s `respond_to`, parallel to
      `format.csv`/`format.pdf`, fetching
      `issues = @query.issues(:limit => Setting.issues_export_limit.to_i)`. Verify by confirming
      the branch exists and is reached (functional test hitting `format: 'xlsx'` with permission
      returns HTTP 200 and `Content-Type` for xlsx).
- [x] 3.2 Build one `Axlsx::Package` with a worksheet named `"Issues"`, write a bold header row
      with columns ID, Subject, Tracker, Status, Priority, Assignee, Updated in that order.
      Verify by parsing the response body in a test (e.g. with `Roo::Excelx` or `caxlsx`'s own
      reader, or by unzipping and checking the shared strings/sheet XML) and asserting the header
      row's text and bold formatting.
- [x] 3.3 Write one data row per issue: ID as a hyperlink cell to `issue_url(issue)`; Subject with
      an explicit `:string` cell type; Tracker/Status/Priority names; Assignee blank when
      `issue.assigned_to.nil?`; Updated via `format_time(issue.updated_on)`. Verify with tests for:
      an issue whose subject starts with `=` (assert the cell is not treated as a formula, i.e.
      its declared type is string), an unassigned issue (assert blank Assignee cell), and the
      hyperlink target on the ID cell equals `issue_url(issue)`.
- [x] 3.4 Handle the empty-result case: confirm the same code path (no special-casing) still
      yields a workbook with only the header row when `issues` is empty. Verify with a functional
      test using a filter that matches zero issues, asserting a 200 response with a valid xlsx
      body containing one worksheet and one row.
- [x] 3.5 Send the workbook via `send_data` with filename
      `"#{filename_for_export(@query, 'issues')}.xlsx"` and the xlsx content type. Verify the
      response's `Content-Disposition` header names a `.xlsx` file and the body is non-empty.

## 4. Regression check on existing formats

- [x] 4.1 Run the existing `IssuesControllerTest` csv and pdf export tests
      (`RAILS_ENV=test bundle exec rails test test/functional/issues_controller_test.rb -n
      "/csv|pdf/"`) and confirm they still pass unchanged, demonstrating `format.csv`/`format.pdf`
      output is untouched by this change.
