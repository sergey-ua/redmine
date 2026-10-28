# Spec Delta

## MODIFIED Requirements

### Requirement: `index`'s CSV and PDF export formats are gated by `export_allowed?` and share one data fetch
The system SHALL guard `format.csv`, `format.pdf` and `format.xlsx` in `IssuesController#index` (app/controllers/issues_controller.rb:45-90) with a single check at line 51: `if (request.format.csv? || request.format.pdf? || request.format.xlsx?) && !export_allowed?(:export_issues, @query.base_scope); deny_access; return; end`. Each export format then independently loads `@query.issues(:limit => Setting.issues_export_limit.to_i)` (lines 82, 87, and the new xlsx branch) — the same call, repeated per format, not a shared `@issues` set computed once for every export format. `format.csv` (lines 81-85) sends the result through `send_data(query_to_csv(issues, @query, params[:csv]), :type => 'text/csv; header=present', :filename => "#{filename_for_export(@query, 'issues')}.csv")`. `format.pdf` (lines 86-89) assigns `@issues` and calls `send_file_headers! :type => 'application/pdf', :filename => "#{filename_for_export(@query, 'issues')}.pdf"`; the actual PDF bytes are produced by rendering `app/views/issues/index.pdf.erb`, which calls `issues_to_pdf(@issues, @project, @query)` (`Redmine::Export::PDF::IssuesPdfHelper#issues_to_pdf`, lib/redmine/export/pdf/issues_pdf_helper.rb:254, mixed into `IssuesHelper`). `format.xlsx` is the third, parallel export branch, covered by its own requirement below.

When `@query` is invalid, the invalid-query branch's `format.any(:atom, :csv, :pdf)` (around line 91) also covers `:xlsx`, so an invalid query returns 422 (`head :unprocessable_content`) for an xlsx request exactly as it already does for csv/pdf, instead of falling through to a 200 with an unguarded or malformed workbook.

`export_allowed?(permission, scope)` (app/controllers/application_controller.rb:580-598, private, exposed via `helper_method`) is: true for `user.admin?`; otherwise, if `@project` is set, false unless `user.allowed_to?(permission, @project)`, and true if `@project.leaf?` (no subprojects); if `@project` is not set (cross-project/global `/issues`), false unless `user.allowed_to?(permission, nil, :global => true)`; in both remaining cases, false if `scope` contains any record whose `project_id` is not in `Project.allowed_to(user, permission)` — this final check is what denies a cross-project or subproject export when the user lacks the permission on at least one project the results would span.

#### Scenario: Export format requested without the export permission
- **WHEN** a non-admin user without the `:export_issues` permission (for the given project or globally) requests `format => 'csv'`, `format => 'pdf'`, or `format => 'xlsx'` on `index`
- **THEN** the controller calls `deny_access` and returns before building `respond_to`'s export branch — a 403, not an empty or partial export file

#### Scenario: Export spans a subproject the user lacks the permission on
- **WHEN** the request has permission on `@project` itself (or is a global, cross-project request with the permission granted globally) but `@query.base_scope` includes issues from a subproject (or another project in a global query) where the user lacks `:export_issues`
- **THEN** the final `scope.where.not(...).exists?` check in `export_allowed?` still denies the export, even though the earlier per-project checks passed, regardless of which of csv, pdf or xlsx was requested

#### Scenario: Invalid query requested as xlsx
- **WHEN** `@query.valid?` is false and the request's format is `xlsx`
- **THEN** the controller responds with `head :unprocessable_content` (422), the same as it does today for an invalid csv or pdf request, and builds no workbook

## ADDED Requirements

### Requirement: `index`'s xlsx export format builds a single-worksheet workbook from the export data fetch
The system SHALL, when `format.xlsx` is requested on `IssuesController#index` and the guard above passes, fetch `issues = @query.issues(:limit => Setting.issues_export_limit.to_i)` (the same call pattern as `format.csv`/`format.pdf`, independently fetched, not a shared `@issues`) and build one workbook with exactly one worksheet named `"Issues"`.

The worksheet SHALL have a header row with exactly these 7 columns, in this order: ID, Subject, Tracker, Status, Priority, Assignee, Updated. The header row's cells SHALL be rendered bold.

For each issue in `issues`, in the order returned by the query (current filters and sort, as `@query.issues` already applies), the system SHALL write one data row with:
- ID: the issue's id, rendered as a hyperlink to `issue_url(issue)` (the full URL, not a relative path).
- Subject: the issue's subject, written with an explicit string/text cell type so that a value beginning with `=`, `+`, `-`, or `@` is never evaluated as a spreadsheet formula.
- Tracker: the issue's tracker name.
- Status: the issue's status name.
- Priority: the issue's priority name.
- Assignee: the assigned user's name, or blank (empty cell) when `issue.assigned_to` is `nil`.
- Updated: the issue's `updated_on` timestamp, formatted through the same user-timezone-aware time formatting used elsewhere in the app (`format_time`).

When `issues` is empty, the system SHALL still send a valid workbook containing the "Issues" worksheet with only the header row (no data rows) — not an error and not an empty/zero-byte response.

The system SHALL send the generated workbook as a file download (not rendered inline) via `send_data`, with filename `"#{filename_for_export(@query, 'issues')}.xlsx"` and an xlsx-appropriate content type, mirroring how `format.csv` sends its result.

This requirement does not change `format.csv` or `format.pdf`, which continue to produce identical output to before this change.

#### Scenario: Workbook structure and header
- **WHEN** a user with export permission requests `index` with `format => 'xlsx'`
- **THEN** the response is a valid xlsx workbook containing exactly one worksheet named "Issues", whose first row has exactly 7 cells reading ID, Subject, Tracker, Status, Priority, Assignee, Updated in that order, rendered bold, and the response is sent as a download named `"#{filename_for_export(@query, 'issues')}.xlsx"`

#### Scenario: ID cell is a clickable hyperlink
- **WHEN** the worksheet is built for an issue
- **THEN** that issue's ID cell is a hyperlink whose target is `issue_url(issue)` (the full URL), not plain text and not a relative path

#### Scenario: Subject is never read as a formula
- **WHEN** an issue's subject starts with `=`, `+`, `-`, or `@` (for example, `=SUM(A1:A2)`)
- **THEN** the Subject cell contains that literal text and is not evaluated as a formula when the workbook is opened

#### Scenario: Unassigned issue leaves Assignee blank
- **WHEN** an issue in the exported result has `assigned_to` set to `nil`
- **THEN** that issue's Assignee cell is blank, not a placeholder string

#### Scenario: Updated column reflects the viewing user's timezone
- **WHEN** the workbook is built for a user with a configured timezone different from the server's
- **THEN** each issue's Updated cell shows `updated_on` formatted in that user's timezone, the same way the rest of the application displays timestamps for that user

#### Scenario: Empty result still produces a valid workbook
- **WHEN** `@query.issues(:limit => Setting.issues_export_limit.to_i)` returns no issues (e.g. filters match nothing)
- **THEN** the response is still a valid xlsx workbook with the "Issues" worksheet containing only the bold header row, sent as a download — not an error response and not an empty body
