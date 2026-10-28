# Proposal

## Why

RED-8 adds an Excel (.xlsx) export of the issue list. Users with the existing export
permission need a way to trigger that download from the issue list page, the same way
they already trigger CSV and PDF export. The issues-views domain owns the other-formats
block where that link lives.

## What Changes

- Add an 'Excel' link to the other-formats block in `app/views/issues/index.html.erb`,
  inside the existing `if export_allowed` branch, alongside 'CSV' and 'PDF'.
- The link is a direct download (`f.link_to_with_query_parameters 'Excel', {:format =>
  'xlsx'}, :class => 'xlsx'`), not a modal like CSV: clicking it downloads immediately.
- It is visible only when `export_allowed?(:export_issues, @query.base_scope)` is true —
  the same permission check already used for CSV and PDF, reused here and not redefined.
- The link targets the `xlsx` format of `IssuesController#index`, an interface owned and
  implemented by the sibling `controllers` domain change; this change only points a link
  at it with the current query parameters.
- This change documents work already committed on branch `factory/RED-8`
  (commit 77e0ed4b2): the view edit and its two `assert_select` test assertions already
  exist. No further application or test code is written by this change.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `issues-views`: the "other-formats block offers CSV, PDF and Atom links, gated by
  `export_allowed`" requirement is rewritten from forward-looking/hedged language about a
  future Excel link to a factual description of the Excel link that now exists.

## Impact

- `app/views/issues/index.html.erb` (lines 37-44): one line added inside the
  `if export_allowed` block (already present in the code, not re-edited by this change).
- `test/functional/issues_controller_test.rb`: two `assert_select` assertions covering
  presence (with permission) and absence (without permission) of `a.xlsx` (already
  present, not re-edited by this change).
- No controller, helper, model, or migration code is touched by this change — those
  belong to the sibling `controllers` and `issues-helpers` domain changes.

## Traceability
Ticket: RED-8
Domain: issues-views
Criteria: AC1
