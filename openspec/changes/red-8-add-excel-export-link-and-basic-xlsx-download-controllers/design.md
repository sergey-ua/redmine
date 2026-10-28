# Design

## Context

`IssuesController#index` (app/controllers/issues_controller.rb:45) already builds csv and pdf
exports inside one `respond_to` block, each guarded by `export_allowed?` and each independently
calling `@query.issues(:limit => Setting.issues_export_limit.to_i)`. This change adds a third,
parallel `format.xlsx` branch and a new runtime dependency (`caxlsx`) to build the workbook in
memory, the same way `format.csv` builds its string in memory (as opposed to `format.pdf`, which
renders an ERB template). See proposal.md - Why/What Changes for the ticket-level motivation.

## Goals / Non-Goals

**Goals:**
- Produce a well-formed `.xlsx` workbook, in-process, with no temp file, matching the column
  spec and safety requirements in the delta spec.
- Reuse the existing guard, data fetch pattern, and filename helper exactly as csv/pdf do, so the
  new branch is a drop-in sibling, not a new code path style.

**Non-Goals:**
- Streaming/chunked generation for very large exports — `Setting.issues_export_limit` already
  caps the row count the same way it caps csv/pdf, so the same bound applies here.
- Any UI change (the Excel link is the `issues-views` sibling change) or filename-helper change
  (the `issues-helpers` sibling change) — both are referenced, not redefined, here.

## Decisions

- **Gem: `caxlsx`.** Pure-Ruby (no native extension, no libxlsxwriter system dependency), already
  the common replacement for the unmaintained `axlsx`, and supports in-memory `to_stream`, bold
  cell styles, hyperlink cells, and explicit cell types (needed to force Subject to a text type)
  — all the primitives this requirement needs. Alternative considered: `rubyXL` (read/write, but
  weaker styling/hyperlink ergonomics) and shelling out to a conversion tool (rejected — adds a
  process dependency and loses in-memory generation parity with csv).
- **In-memory generation, like csv not like pdf.** `format.pdf` renders `index.pdf.erb`, which
  calls a helper (`issues_to_pdf`) that builds the `Prawn` document. xlsx instead builds the
  workbook directly in the controller action and calls `send_data` with the serialized bytes
  (`package.to_stream.read`), matching `format.csv`'s `send_data(query_to_csv(...))` shape more
  closely than pdf's shape, since there is no analogous ERB template to render for a binary
  spreadsheet format. No new file is added for this (no `index.xlsx.erb`); the workbook-building
  code lives inline in the `format.xlsx` block, mirroring csv's inline `send_data` call. If this
  grows (e.g. a reusable `issues_to_xlsx` helper is wanted later), that is an out-of-scope
  refactor — the ticket's scope is "basic .xlsx download," one inline block.
- **Cell typing for Subject.** `caxlsx` writes a cell as a formula only when its value is a
  `String` starting with `=` AND the cell's type isn't explicitly set to `:string`; setting
  `:type => :string` (or inlining `add_row [...], :types => [...]`) on the Subject column
  guarantees literal text regardless of leading character, satisfying the formula-injection
  requirement for all four risky leading characters (`=`, `+`, `-`, `@`), not just `=`.
- **Guard extension location.** The single `if (request.format.csv? || request.format.pdf?) &&
  !export_allowed?(...)` check at line 51 gains `|| request.format.xlsx?` rather than a second,
  separate check, so the three export formats keep exactly one gate — consistent with the
  existing `controllers` spec's framing of a single shared guard.

## Risks / Trade-offs

- [New runtime dependency pulls in transitive gems] → `caxlsx` is pure Ruby with a small
  dependency footprint (`rubyzip`, `htmlentities`); `Gemfile.lock` is tracked and pins
  `caxlsx (4.5.0)`, so the lockfile must be committed with the `Gemfile` change and `bundle install`
  must resolve cleanly before merging.
- [Large exports hold the whole workbook in memory before sending] → bounded by the existing
  `Setting.issues_export_limit`, the same bound csv/pdf already accept; no new exposure.
- [Guard/branch duplication (csv/pdf/xlsx each repeat the fetch and guard condition)] → accepted
  as consistent with the existing style (the main spec already documents this as "not a shared
  `@issues` set"); refactoring that pattern is out of scope for this ticket.
