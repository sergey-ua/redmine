# Tasks

- [x] 1. Add a test asserting the shared `export_allowed?` guard denies `format => 'csv'`, `format => 'pdf'`, and `format => 'xlsx'` identically on `IssuesController#index` for a user without `:export_issues` (near `test_index_csv` / `test_index_pdf` in `test/functional/issues_controller_test.rb`).
- [x] 2. Add a test asserting the invalid-query `format.any(:atom, :csv, :pdf, :xlsx)` fallback still returns 422 (`head :unprocessable_content`) for `format => 'csv'` and `format => 'pdf'` requests, with `:xlsx` present in the list.
- [x] 3. Run `test_index_csv` and `test_index_pdf` (existing tests, unmodified) to confirm they still pass as the regression baseline.
- [x] 4. Run the new and existing tests together: `RAILS_ENV=test bundle exec rails test test/functional/issues_controller_test.rb -n "/export|csv|pdf/"`.
- [x] 5. Confirm no other `export_allowed?` call site (timelog_controller.rb, gantts_controller.rb, reports_controller.rb, issues_controller.rb#retrieve_previous_and_next_issue_ids) needs a change or test — out of scope per design.md "Also affected" (RED-8 did not change `export_allowed?`'s body/signature).
- [x] 6. `openspec validate red-11-regression-check-csv-and-pdf-exports-unaffected-controllers` passes.
