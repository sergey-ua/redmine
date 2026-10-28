# Tasks

## 1. Spec delta

- [x] 1.1 Write the MODIFIED-requirement delta for `filename_for_export` in `specs/issues-helpers/spec.md`, copying the full existing requirement text from `openspec/specs/issues-helpers/spec.md` and adding the new "xlsx export format calls the same filename helper" scenario — verify by diffing the copied body against the main spec (identical except the added scenario).
- [x] 1.2 Confirm `query_to_csv`'s requirement is left out of this change's delta (reference-only, unchanged) — verify by checking the delta file contains no `query_to_csv` section.

## 2. Validation

- [x] 2.1 Run `openspec validate red-8-add-excel-export-link-and-basic-xlsx-download-issues-helpers --strict` from the repository root and fix any reported issues — verify the command exits 0.
- [x] 2.2 Run `git status --short` in the repository and confirm only paths under `openspec/changes/red-8-add-excel-export-link-and-basic-xlsx-download-issues-helpers/` are new/changed — verify no `app/`, `test/`, or `openspec/specs/` paths appear.
