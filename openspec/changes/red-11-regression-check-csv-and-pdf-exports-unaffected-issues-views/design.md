# Design

## Context

RED-8 added the Excel (`.xlsx`) export link between the existing PDF and Atom links in the issues list's other-formats menu (`app/views/issues/index.html.erb:37-42`). RED-11 is the regression-check ticket covering the CSV and PDF export links' continued correctness. This change is test-only: it adds/extends automated test coverage in `test/functional/issues_controller_test.rb`. No application code is changed.

## Files / symbols involved

- **To be changed (apply step):** `test/functional/issues_controller_test.rb` — add/extend test methods (see below).
- **Read-only references (not changed):**
  - `app/views/issues/index.html.erb` (lines ~37-42) — `export_allowed` computed once; `other_formats_links do |f| ... end` block renders CSV (`f.link_to_with_query_parameters 'CSV', {}, :onclick => "showModal(...)"`), PDF (`f.link_to_with_query_parameters 'PDF'`), Excel (`f.link_to_with_query_parameters 'Excel', {:format => 'xlsx'}, :class => 'xlsx'`), Atom (`f.link_to_with_query_parameters 'Atom', :key => ...`), in that order.
  - `lib/redmine/views/other_formats_builder.rb:35` — `link_to_with_query_parameters`, the helper every format link (CSV/PDF/Excel/Atom) calls through. Confirmed unaffected by RED-8; not changed by this ticket.

## New/extended test methods

1. **Other-formats link DOM order (CSV, PDF, Excel, Atom).**
   Issue a GET to `/issues` with export permission granted, then use `assert_select`/`css_select` against the other-formats `<p>`/`<a>` elements to assert the `class` attribute sequence is `['csv', 'pdf', 'xlsx', 'atom']` (or equivalent order-sensitive assertion), confirming Excel was inserted between PDF and Atom without disturbing CSV/PDF order.

2. **CSV and PDF link attributes unchanged with Excel present.**
   Issue a single GET to `/issues` (with query params, e.g. a filter/sort, so the "preserve query params minus page" behavior is exercised) with export permission granted. From that one response:
   - Assert the CSV link's text is `'CSV'`, it carries the modal-opening `onclick` attribute (`showModal('csv-export-options', ...)`), `rel="nofollow"`, and an href containing no `format=` override plus the preserved query params minus `page`.
   - Assert the PDF link's text is `'PDF'`, `rel="nofollow"`, and an href containing `format=pdf` plus the preserved query params minus `page`.
   - Assert the Excel link is also present in the same response (class `xlsx`), proving the CSV/PDF assertions are not from an Excel-free response.

These may be implemented as new test methods or as extensions to existing ones (e.g. extending `test_index_should_omit_page_param_in_export_links` to also assert CSV/PDF text and attributes), whichever keeps the test file more maintainable; either satisfies the acceptance criteria.

## Also affected

- `lib/redmine/views/other_formats_builder.rb:35` (`link_to_with_query_parameters`) — unaffected; read-only reference, not changed by this ticket.
- `app/controllers/issues_controller.rb` `export_allowed?` call site (L51) — out of scope for this domain; owned by the sibling `controllers` change for RED-11. Not touched here.
- `test/functional/issues_controller_test.rb:737` `test_index_should_omit_page_param_in_export_links` and `:827` `test_index_without_export_issues_permission_should_hide_export_links_and_deny_export_requests` — must be run (not changed, unless extended per the note above) to confirm they still pass after the new/extended tests are added, i.e. no regression was introduced to existing export-link coverage.

## Testing

In the apply step, once the test DB/bundle are set up:
- `bin/rails test test/functional/issues_controller_test.rb -n test_<order_assertion_method_name>`
- `bin/rails test test/functional/issues_controller_test.rb -n test_<csv_pdf_attribute_assertion_method_name>`
- `bin/rails test test/functional/issues_controller_test.rb -n test_index_should_omit_page_param_in_export_links`
- `bin/rails test test/functional/issues_controller_test.rb -n test_index_without_export_issues_permission_should_hide_export_links_and_deny_export_requests`
