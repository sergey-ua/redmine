# Design

## Context
RED-8 (merged via PR #8, commit bec54f5) added `format.xlsx` to `IssuesController#index`'s export dispatch, appending `request.format.xlsx?` to the existing guard `||` and `:xlsx` to the invalid-query `format.any(...)` list. Reading `app/controllers/issues_controller.rb` (guard at line 51, `format.csv` at 81-85, `format.pdf` at 86-89, `format.xlsx` at 90-106, invalid-query fallback ~112) and `app/controllers/application_controller.rb:580-598` (`export_allowed?`) confirms the csv/pdf branches and the guard's body are byte-identical to before RED-8 — xlsx is a parallel, separate block reusing none of csv/pdf's internals. See proposal.md - Why for the motivation.

## Goals / Non-Goals

**Goals:**
- Add automated regression tests pinning that the shared `export_allowed?` guard and the csv/pdf branches of `IssuesController#index` behave identically with xlsx present.
- Confirm (by running the suite) that the existing `test_index_csv` / `test_index_pdf` tests still pass unmodified.

**Non-Goals:**
- No change to `app/controllers/issues_controller.rb` or `app/controllers/application_controller.rb`.
- No coverage of the export menu/link rendering (sibling change `red-11-regression-check-csv-and-pdf-exports-unaffected-issues-views`) or of `query_to_csv`/`filename_for_export` body/filename content (sibling change `red-11-regression-check-csv-and-pdf-exports-unaffected-issues-helpers`).
- No new xlsx-specific test coverage (already covered by RED-8's own change).

## Decisions
- **Test-only change, no spec text rewrite beyond one ADDED scenario.** The controllers main spec already documents the post-RED-8 behaviour accurately (confirmed by direct code reading); rewriting requirement prose would not change what the system does. Instead the MODIFIED delta reproduces the existing requirement verbatim and appends one scenario describing the regression test, per the OpenSpec MODIFIED-requirements rule (full block, not partial).
- **New tests live in `test/functional/issues_controller_test.rb`**, next to `test_index_csv` (~line 816) and `test_index_pdf` (~line 1259), rather than a new test file — they exercise the same controller action and fixtures as the existing export tests.
- **Three regression tests, not one:** (1) a parameterized/explicit assertion that the guard denies csv, pdf and xlsx identically for a user lacking `:export_issues` (exercises the shared `||` condition as one unit, catching a regression where one format's condition diverges from the others); (2) an assertion that the invalid-query `format.any` fallback still returns 422 for csv and pdf with xlsx in the list; (3) no new test for the success path — the existing `test_index_csv`/`test_index_pdf` already cover it and are the regression baseline; this change's task list includes running them to confirm they still pass.

## Risks / Trade-offs
- [Tests could pass trivially without exercising the shared guard if fixtures grant `:export_issues` broadly] → Mitigation: use a role/user fixture combination already known (from the existing test file) to lack `:export_issues`, mirroring how existing permission-denial tests in this file are written.
- [Spec delta risks drifting from code if a later change touches the guard without updating both] → Mitigation: the delta's scenario text references the exact guard line/condition already in the main spec, so a future MODIFIED delta on this requirement will have to touch both together.

## Also affected (carried from exploration)
- `app/controllers/timelog_controller.rb` (`#index` line 46, `#report` line 82), `app/controllers/gantts_controller.rb#show` (line 40), `app/controllers/reports_controller.rb#issue_report_details` (line 47), `app/controllers/issues_controller.rb#retrieve_previous_and_next_issue_ids` (line 570) — all call `export_allowed?`. **Unaffected and out of scope**: RED-8 did not change `export_allowed?`'s body or signature; these other call sites are untouched and don't handle xlsx. No task needed.
- `query_to_csv`, `filename_for_export` (app/helpers/queries_helper.rb) — called unchanged by `format.csv`/`format.pdf` at issues_controller.rb:84/88. Owned and tested by the sibling `issues-helpers` change; this change only confirms the controller still calls them the same way (via `test_index_csv`/`test_index_pdf` passing).

## Testing
- `RAILS_ENV=test bundle exec rails test test/functional/issues_controller_test.rb -n "/export|csv|pdf/"` after adding the new tests, to confirm the new regression tests and the pre-existing `test_index_csv`/`test_index_pdf` all pass.
