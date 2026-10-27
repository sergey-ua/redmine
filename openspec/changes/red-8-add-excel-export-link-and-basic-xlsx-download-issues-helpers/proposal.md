# Proposal

## Why

RED-8 adds an xlsx export to the issue list, alongside the existing csv/pdf exports. The sibling `controllers` change will add a third caller of `QueriesHelper#filename_for_export(query, 'issues')` (the helper that builds the shared download filename) and append `.xlsx` to it, exactly as the csv and pdf callers already append their own extensions. The current `issues-helpers` main spec documents the filename contract generically ("a new export format follows the same pattern") but does not yet record that xlsx is a confirmed concrete instance of that pattern. This change closes that gap in the spec so the contract xlsx relies on is explicit and traceable, without changing any helper code.

## What Changes

- Document (via a spec delta only — no code change) that `filename_for_export(@query, 'issues')` is reused unmodified by the new xlsx export format, which calls it once and appends `.xlsx` itself, the same call-then-append pattern used by csv (`.csv`) and pdf (`.pdf`).
- No change to `filename_for_export` itself: it is already format-agnostic and needs no modification to support xlsx.
- No change to `query_to_csv`: it remains CSV-specific and reference-only; this change does not touch its requirement.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `issues-helpers`: the requirement "`filename_for_export` builds the download filename shared by every export format; the format extension is appended by the caller" gains one additional scenario confirming xlsx follows the existing call-then-append pattern. No other requirement in this capability changes.

## Impact

- Affected spec: `openspec/specs/issues-helpers/spec.md` (one requirement modified via delta; applied only on archive).
- Affected code: none. `app/helpers/queries_helper.rb:343` (`filename_for_export`) and `app/helpers/queries_helper.rb:330` (`query_to_csv`, reference only) are unchanged.
- Related call sites (owned by the sibling `controllers` change, not this one): `app/controllers/issues_controller.rb:84` (`format.csv`), `:88` (`format.pdf`), and the new xlsx call site the `controllers` change adds following the same pattern.
- No test changes belong to this domain.
