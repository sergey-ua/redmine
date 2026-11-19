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

#### Scenario: Regression coverage proves the helper is unchanged now that xlsx reuses it
- **WHEN** `test/helpers/queries_helper_test.rb` calls `filename_for_export(query, 'issues')` directly, once with no query name (and no `params[:query_name]`) and once with `params[:query_name] = 'My Query Name'`
- **THEN** the unit test asserts the results `"issues"` and `"my_query_name"` respectively, giving direct evidence — independent of the controller and of any export format — that the helper's CSV/PDF filename behavior is still exactly what it was before the xlsx export format existed

### Requirement: `query_to_csv` is CSV-specific and not reusable as-is for another export format
The system SHALL build the CSV body in `QueriesHelper#query_to_csv(items, query, options={})` (app/helpers/queries_helper.rb:330-341) by iterating `query.columns`, writing a header row of `column.caption`, then one row per item via `csv_content(c, item)` into a `Redmine::Export::CSV.generate` block. This method is CSV-format-specific (it returns CSV text through `csv <<`); a new export format does not call into it and instead builds its own output from `query.columns`/`csv_content`-equivalent value extraction, or iterates `items` directly for a fixed column set.

#### Scenario: A new export format needs issue field values
- **WHEN** a new export format (not CSV, not PDF) needs the same per-issue field values CSV exports (ID, subject, tracker, status, etc.)
- **THEN** it reads those values directly off the `Issue` records (e.g. `issue.id`, `issue.subject`, `issue.tracker`, `issue.status`) or via `csv_content(column, item)` (queries_helper.rb) for values that need `query.columns`-driven formatting, rather than depending on `query_to_csv`'s CSV-shaped return value

#### Scenario: Regression coverage proves the CSV body builder is unchanged now that xlsx exists
- **WHEN** `test/helpers/queries_helper_test.rb` calls `query_to_csv(items, query)` directly for a simple query and a small set of items
- **THEN** the unit test asserts the returned CSV text's header row matches `query.columns.map(&:caption)` and each following row matches `csv_content(column, item)` per item, giving direct evidence — independent of the controller and of the xlsx format, which builds its own rows and never calls `query_to_csv` — that the CSV body is still exactly what it was before xlsx existed
