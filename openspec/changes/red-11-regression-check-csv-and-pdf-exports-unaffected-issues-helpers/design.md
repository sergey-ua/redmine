# Design

## Context

See proposal.md - Why. `QueriesHelper#query_to_csv` and `QueriesHelper#filename_for_export` (app/helpers/queries_helper.rb:330-348) are today exercised only indirectly, through `IssuesController` functional tests (test/functional/issues_controller_test.rb: `test_index_csv`, `test_index_csv_filename_without_query_name_param`, `test_index_csv_filename_with_query_name_param`, `test_index_pdf`). RED-8 added an xlsx branch to `IssuesController#index` that calls `filename_for_export` but builds its own CSV-unrelated rows rather than calling `query_to_csv`. Both helper methods are confirmed unchanged by RED-8 (exploration-red-11-regression-check-csv-and-pdf-exports-unaffected-issues-helpers.md).

## Goals / Non-Goals

**Goals:**
- Add direct unit-level regression tests for `query_to_csv` and `filename_for_export` in `test/helpers/queries_helper_test.rb`, so a future change to either helper (including further export-format work) gets a fast, localized failure instead of only a controller-level one.

**Non-Goals:**
- Changing `app/helpers/queries_helper.rb` or any other application code.
- Testing the controller's `format.csv`/`format.pdf`/`format.xlsx` dispatch or response headers (owned by the `controllers` sibling change).
- Testing the export menu/link markup (owned by the `issues-views` sibling change).

## Decisions

- **Add tests to the existing `test/helpers/queries_helper_test.rb`, not a new file.** The file already exists (`QueriesHelperTest < Redmine::HelperTest`, `include QueriesHelper`) and already tests other `QueriesHelper` methods (e.g. `filters_options_for_select`) the same way: instantiate a query, call the helper method directly. Alternative considered: a new `test/unit/query_to_csv_test.rb` — rejected, no benefit over reusing the established helper-test file and its `Redmine::HelperTest` setup (fixtures, `User.current`).
- **Use a plain `IssueQuery` with default columns against fixture issues**, the same construction `test_filters_options_for_select_should_have_a_blank_option` already uses (`IssueQuery.new`), rather than mocking `Issue`/`Query`. Keeps the test a true characterization of production objects, matching how `IssuesController#index` builds `@query`/`@query.issues`.
- **Assert against `query.columns.map(&:caption)` and `csv_content(column, item)` rather than hard-coded strings** for the CSV body test, so the test documents the *relationship* `query_to_csv` SHALL maintain (header from captions, rows from `csv_content`) per the spec's "`query_to_csv` is CSV-specific" requirement, rather than being a brittle snapshot of today's fixture data.
- **Set `params[:query_name]` directly** (`Redmine::HelperTest` exposes `params` the way `QueriesHelperTest`'s existing tests already rely on `User.current`/`with_locale`) for the "query name given" filename case, mirroring how `IssuesController#index` reads `params[:query_name]`.

## Risks / Trade-offs

- [Characterization tests could encode an existing bug as "correct" if one existed] → Not a concern here: the exploration already confirmed both methods against the main spec's existing, already-reviewed requirements and scenarios; the tests assert the documented contract, not arbitrary current output.
- [Fixture-dependent column captions could change if fixtures change] → Mitigated by asserting against `query.columns.map(&:caption)` computed in the test itself rather than a literal list, so the test tracks the query's actual columns.

## Files and symbols touched
- `test/helpers/queries_helper_test.rb` — add `test_query_to_csv_should_return_header_and_one_row_per_item`, `test_filename_for_export_without_query_name`, `test_filename_for_export_with_query_name_param`. No other file changes.
