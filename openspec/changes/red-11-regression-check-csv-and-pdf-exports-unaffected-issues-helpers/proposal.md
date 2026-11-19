# Proposal

## Why

RED-8 added an xlsx export format to `IssuesController#index`, reusing the shared `QueriesHelper` helpers `filename_for_export` and `query_to_csv`. RED-11 requires automated proof that the existing CSV and PDF export link, action, and output are unchanged now that xlsx exists. This change covers the shared helper layer: it adds direct unit-level regression tests pinning `query_to_csv`'s CSV body and `filename_for_export`'s filename output, which today are only exercised indirectly through controller functional tests.

## What Changes

- Add unit tests to `test/helpers/queries_helper_test.rb` that characterize `query_to_csv(items, query)`'s CSV body output (header row from `column.caption`, one data row per item via `csv_content`) for a simple query, independent of the xlsx format.
- Add unit tests for `filename_for_export(query, 'issues')` covering both documented input cases: no `query.name`/`params[:query_name]` (falls back to `default_name`), and a `params[:query_name]` given (titleized/downcased).
- No application code changes: `app/helpers/queries_helper.rb` is confirmed unchanged by RED-8; xlsx calls `filename_for_export` but not `query_to_csv`.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `issues-helpers`: the requirements for `filename_for_export` and `query_to_csv` gain scenarios describing the new direct unit-test regression coverage that proves their behavior is unchanged now that the xlsx export format exists and reuses `filename_for_export`.

## Impact

- Affected code: `test/helpers/queries_helper_test.rb` only (new tests added; no application code changes).
- Affected specs: `openspec/specs/issues-helpers/spec.md` (two requirements gain a scenario each; no behavior changes).
- Out of scope for this change (covered by sibling changes): export link/menu markup (`issues-views` domain) and controller dispatch/response identity (`controllers` domain).

## Traceability
- Ticket: RED-11
- Domain: issues-helpers
- Criteria: C7 (acceptance criteria 1 and 2, as far as the shared helper layer is responsible for CSV body and CSV/PDF filename output)
