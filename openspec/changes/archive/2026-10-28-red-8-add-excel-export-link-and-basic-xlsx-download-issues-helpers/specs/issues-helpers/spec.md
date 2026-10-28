# Spec Delta

## MODIFIED Requirements

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
