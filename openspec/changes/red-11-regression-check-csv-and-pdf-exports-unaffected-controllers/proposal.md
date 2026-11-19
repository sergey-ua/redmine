# Proposal

## Why
RED-8 added the xlsx export format to `IssuesController#index`, extending the shared export guard and the `respond_to` dispatch. RED-11 is the regression check that must pin, with automated tests, that this extension did not alter the CSV and PDF controller actions or the shared `export_allowed?` guard they depend on. Without this, a later change to the xlsx branch could silently regress csv/pdf behaviour and nothing would catch it.

## What Changes
- No application code changes. This change adds controller-level regression test coverage in `test/functional/issues_controller_test.rb` asserting: the shared `export_allowed?` guard denies csv, pdf and xlsx identically for a user without `:export_issues`; the invalid-query `format.any(:atom, :csv, :pdf, :xlsx)` fallback still returns 422 for csv and pdf (with xlsx present in the list); and the existing `test_index_csv`/`test_index_pdf` tests keep passing unmodified as the regression baseline.
- Adds one scenario to the existing "`index`'s CSV and PDF export formats are gated by `export_allowed?` and share one data fetch" requirement in `openspec/specs/controllers/spec.md`, documenting this regression coverage. No requirement text is modified — the spec already accurately describes the post-RED-8 behaviour.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `controllers`: ADD a scenario to the existing "`index`'s CSV and PDF export formats are gated by `export_allowed?` and share one data fetch" requirement, describing the regression test that confirms the shared guard and csv/pdf behaviour are unaffected by the xlsx addition. No existing requirement text changes.

## Impact
- Test-only: `test/functional/issues_controller_test.rb` gains new test methods near `test_index_csv` (~line 816) and `test_index_pdf` (~line 1259).
- No changes to `app/controllers/issues_controller.rb` or `app/controllers/application_controller.rb`.
- Sibling changes `red-11-regression-check-csv-and-pdf-exports-unaffected-issues-views` (export menu/link rendering) and `red-11-regression-check-csv-and-pdf-exports-unaffected-issues-helpers` (`query_to_csv`/`filename_for_export`) cover the other two acceptance-criteria facets ("link" and CSV body/filename) independently.

## Traceability
Ticket: RED-11
Domain: controllers
Criteria: C7
