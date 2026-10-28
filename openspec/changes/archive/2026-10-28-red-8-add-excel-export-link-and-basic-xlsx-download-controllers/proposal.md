# Proposal

## Why

The issue list currently offers CSV and PDF export but not Excel, which the ticket (RED-8)
asks for because stakeholders consume issue data in spreadsheets more than plain CSV
(formatting, hyperlinks). This domain covers the controller side: the `xlsx` response format
that `IssuesController#index` must produce, guarded the same way CSV/PDF already are.

## What Changes

- Extend the `index` action's export-permission guard (`app/controllers/issues_controller.rb:51`)
  to also cover `request.format.xlsx?`, and extend the invalid-query branch's
  `format.any(:atom, :csv, :pdf)` to include `:xlsx`, so an invalid query or a missing export
  permission is rejected for xlsx exactly as it already is for csv/pdf.
- Add a `format.xlsx` branch to `index`'s `respond_to` block that fetches
  `@query.issues(:limit => Setting.issues_export_limit.to_i)` (the same call pattern as csv/pdf,
  not a shared fetch) and builds a single-worksheet (`"Issues"`) `.xlsx` workbook: columns ID,
  Subject, Tracker, Status, Priority, Assignee, Updated in that order, bold header row, ID cells
  as hyperlinks to `issue_url(issue)`, Subject written as literal text (never evaluated as a
  formula even if it starts with `=`/`+`/`-`/`@`), Assignee blank when unassigned, Updated via the
  user-timezone-aware time helper. An empty result still sends a workbook with only the header
  row. Sent via `send_data` with `filename_for_export(@query, 'issues') + '.xlsx'`.
- Add the `caxlsx` runtime gem to the `Gemfile` (pure Ruby, no native extension) to build the
  workbook.
- `format.csv` and `format.pdf` are not changed.

## Capabilities

### New Capabilities
(none — this domain only extends an existing capability)

### Modified Capabilities
- `controllers`: the `index` export guard and export-format `respond_to` branches gain an `xlsx`
  format, parallel to the existing `csv`/`pdf` ones.

## Impact

- `app/controllers/issues_controller.rb`: `index` — guard at line 51, invalid-query branch around
  line 91, new `format.xlsx` block parallel to `format.csv`/`format.pdf` (lines 81-89).
- `Gemfile`: new runtime dependency `caxlsx`.
- No other controller, model, helper, or view code changes in this domain. The Excel export link
  in `app/views/issues/index.html.erb` is owned by the sibling `issues-views` change; the
  `filename_for_export` helper (`app/helpers/queries_helper.rb:343`) is owned by the sibling
  `issues-helpers` change and is only called here, unchanged.

## Traceability

Ticket: RED-8
Domain: controllers
Criteria: AC2, AC3, AC4, AC5
