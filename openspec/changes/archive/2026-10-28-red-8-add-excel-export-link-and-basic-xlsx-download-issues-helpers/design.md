# Design

## Context

See proposal.md - Why. This change touches no application code; it only records in the `issues-helpers` main spec that `filename_for_export(query, 'issues')` (app/helpers/queries_helper.rb:343-348) is reused unmodified by the new xlsx export, following the call-then-append pattern already used by csv and pdf (issues_controller.rb:84, 88).

## Goals / Non-Goals

**Goals:**
- Record, as a spec delta, that xlsx is a confirmed third caller of `filename_for_export` following the existing call-then-append pattern.

**Non-Goals:**
- Specifying the xlsx worksheet format, headers, or hyperlinks (owned by the sibling `controllers` change).
- Specifying the Excel export link in the view (owned by the sibling `issues-views` change).
- Any change to `filename_for_export` or `query_to_csv` code or behavior.

## Decisions

- **No code change.** `filename_for_export` already takes `default_name` as a plain string and has no format-specific logic; confirmed by reading app/helpers/queries_helper.rb:343-348 and both existing callers at issues_controller.rb:84 and :88. The new xlsx caller (added by the sibling `controllers` change) needs nothing from this helper beyond what csv/pdf already use. Alternative considered: adding an xlsx-specific branch or default name — rejected, no such branch exists for csv or pdf either, so adding one for xlsx would be unnecessary and inconsistent.
- **Delta modifies the existing requirement rather than adding a new one.** The requirement already generalizes ("a new export format follows the same pattern"); adding a confirming scenario is more faithful than introducing a parallel ADDED requirement that would duplicate the same contract.
- **`query_to_csv`'s requirement is untouched.** It is reference-only per the task boundary and its existing scenario already generalizes to "not CSV, not PDF" without naming xlsx specifically.

## Also Affected (carried from exploration)

- `app/controllers/issues_controller.rb:84,88` (existing csv/pdf call sites) — reference only, not modified by this change. The sibling `controllers` change adds the third (xlsx) call site there, following this documented pattern.
- Existing tests `test_index_csv_filename_without_query_name_param` and `test_index_csv_filename_with_query_name_param` — untouched; no test belongs to this domain. Any xlsx-filename assertion belongs to the `controllers` change's tests.

## Risks / Trade-offs

- [Risk] A reader could mistake this documentation-only delta for a code change request. → Mitigation: proposal.md and this design explicitly state no application or test files are touched; tasks.md only requires the spec delta and validation.

## Testing

No new or modified tests — this change produces no behavior change to verify at runtime. Verification is `openspec validate red-8-add-excel-export-link-and-basic-xlsx-download-issues-helpers --strict` confirming the delta is well-formed and the requirement header matches the main spec exactly.
