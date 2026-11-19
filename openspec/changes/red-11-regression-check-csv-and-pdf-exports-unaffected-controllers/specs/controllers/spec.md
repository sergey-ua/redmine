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

#### Scenario: CSV and PDF export remain unaffected by the xlsx format's presence
- **WHEN** a regression test requests `index` with `format => 'csv'` or `format => 'pdf'` after the xlsx format has been added to the controller
- **THEN** the shared guard denies csv, pdf and xlsx identically for a user without `:export_issues`; the invalid-query fallback (`format.any(:atom, :csv, :pdf, :xlsx)`) still returns 422 for csv and pdf with xlsx present in the list; and the existing csv/pdf success-path tests (`test_index_csv`, `test_index_pdf`) continue to pass unmodified, confirming no shared logic for csv/pdf was altered by the xlsx addition
