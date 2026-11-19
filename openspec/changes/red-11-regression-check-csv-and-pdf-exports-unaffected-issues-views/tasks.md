# Tasks

- [ ] 1. Add a test method asserting the other-formats link DOM order is CSV, PDF, Excel (`xlsx`), Atom, via `assert_select`/`css_select` checking the `class` attribute sequence `['csv', 'pdf', 'xlsx', 'atom']`.
- [ ] 2. Add/extend a test method asserting, from a single response (export permission granted, with query params present) that also contains the Excel link:
  - [ ] 2a. CSV link text, `onclick` modal-opening attribute, `rel="nofollow"`, and href (no format override, query params preserved minus `page`) are unchanged.
  - [ ] 2b. PDF link text, `rel="nofollow"`, and href (`format=pdf`, query params preserved minus `page`) are unchanged.
  - [ ] 2c. Excel link (class `xlsx`) is present in the same response, confirming assertions 2a/2b are not from an Excel-free request.
- [ ] 3. Run the pre-existing tests to confirm no regression was introduced:
  - [ ] 3a. `bin/rails test test/functional/issues_controller_test.rb -n test_index_should_omit_page_param_in_export_links`
  - [ ] 3b. `bin/rails test test/functional/issues_controller_test.rb -n test_index_without_export_issues_permission_should_hide_export_links_and_deny_export_requests`
- [ ] 4. Run the new/extended tests from tasks 1-2 and confirm they pass:
  - [ ] 4a. `bin/rails test test/functional/issues_controller_test.rb -n <order_assertion_test_name>`
  - [ ] 4b. `bin/rails test test/functional/issues_controller_test.rb -n <csv_pdf_attribute_assertion_test_name>`
