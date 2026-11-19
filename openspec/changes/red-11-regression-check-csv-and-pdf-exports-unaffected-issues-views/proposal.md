# Proposal

## Why

RED-8 added an Excel (`.xlsx`) export link to the issues list's other-formats menu, inserted between the existing PDF and Atom links (`app/views/issues/index.html.erb:41`). RED-11 is the regression-check ticket for that change: it requires automated test proof that the pre-existing CSV and PDF export links (text, href, query params, modal-opening attribute, order relative to each other) are unchanged now that Excel sits between PDF and Atom. This domain (issues-views) owns only the link/menu-rendering half of that proof; the controller dispatch/action and CSV/PDF response-body behavior belong to sibling changes.

## What Changes

- Add/extend functional test coverage in `test/functional/issues_controller_test.rb` asserting:
  - The other-formats link DOM order is CSV, PDF, Excel (`xlsx`), Atom.
  - The CSV link's text, `onclick` (modal-opening), `rel=nofollow`, and href (format + preserved query params minus `page`) are unchanged.
  - The PDF link's text, `rel=nofollow`, and href (format + preserved query params minus `page`) are unchanged.
  - Both assertions are made against the same response that also contains the Excel link, not a separate xlsx-only request.
- No application code changes. `app/views/issues/index.html.erb` and `lib/redmine/views/other_formats_builder.rb` are read-only references for this change — their current behavior is already correct and already documented in `openspec/specs/issues-views/spec.md`.
- No changes to `openspec/specs/`. This change is test-only; its spec delta documents the regression coverage being added without altering any already-correct requirement text.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `issues-views`: no requirement text changes. The existing requirement "The other-formats block offers CSV, PDF and Atom links, gated by `export_allowed`" already documents the CSV/PDF/Excel/Atom order and CSV-modal vs. PDF-direct-link behavior correctly (added by the RED-8 proposal, not altered here). This change adds one new scenario to that same requirement asserting CSV/PDF link attributes (href, onclick, rel) are unaffected by Excel's presence, to make the regression explicit and traceable to a scenario, per openspec delta conventions requiring every covered acceptance criterion to map to a requirement/scenario.

## Impact

- Affected test file: `test/functional/issues_controller_test.rb` (new/extended test methods only; to be written in the apply step).
- Affected read-only references: `app/views/issues/index.html.erb`, `lib/redmine/views/other_formats_builder.rb` (unchanged).
- Out of scope: `app/controllers/issues_controller.rb` export dispatch/`export_allowed?` call site and CSV/PDF output-body behavior — owned by sibling (controllers) changes for RED-11.

## Traceability

Ticket: RED-11
Domain: issues-views
Criteria: C7 (AC1 CSV export link unchanged; AC2 PDF export link unchanged)
