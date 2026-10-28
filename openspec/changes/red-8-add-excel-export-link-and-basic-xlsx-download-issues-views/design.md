# Design

## Context

See proposal.md - Why. The Excel link and its test already exist on branch `factory/RED-8`
(commit 77e0ed4b2); this design documents the shape of that existing code so the spec delta
and tasks match what is in the repository, not a plan to write new code.

Files and symbols touched:
- `app/views/issues/index.html.erb:37-44` — the `export_allowed` local, the
  `other_formats_links do |f| ... end` block, and the new line
  `f.link_to_with_query_parameters 'Excel', {:format => 'xlsx'}, :class => 'xlsx'` inside
  the `if export_allowed` branch, between 'PDF' and 'Atom'.
- `test/functional/issues_controller_test.rb:743,835` — `assert_select 'a.xlsx[href="/issues.xlsx"]'`
  (with export permission) and `assert_select 'p.other-formats a.xlsx', 0` (without).

## Goals / Non-Goals

**Goals:**
- Make the issues-views main spec state, as fact, that the other-formats block offers an
  Excel link gated by `export_allowed`, matching the code already on the branch.

**Non-Goals:**
- Does not implement or modify the `.xlsx` format action, the workbook content, or the
  permission check itself — those belong to the sibling `controllers` and
  `issues-helpers` changes.
- Does not add new tests; the two existing `assert_select` assertions already cover AC1.

## Decisions

- **Direct link, no modal**: `f.link_to_with_query_parameters 'Excel', {...}` is called
  with no `:onclick`, unlike 'CSV'. Rationale: the ticket requires the download to start
  immediately on click, with no options dialog (CSV has export options like column
  selection; Excel's basic export does not).
- **Explicit `{:format => 'xlsx'}, :class => 'xlsx'`**: `link_to_with_query_parameters`
  derives its format and CSS class from the link text by default, which would produce
  `'excel'`/`format=excel`. Passing both explicitly makes the link target the `.xlsx`
  format that the `controllers` change implements, and keeps the CSS class consistent
  with the format name used elsewhere (`a.xlsx`, matching the existing test's selector).
- **Placement between PDF and Atom**: keeps CSV/PDF/Excel grouped inside the
  `if export_allowed` guard, with the unconditional Atom link last, preserving the
  existing block's structure.

## Also affected

Carried from the exploration file's "Also affected" section (issues-views domain):
- `lib/redmine/views/other_formats_builder.rb:35` (`link_to_with_query_parameters`) —
  unaffected: consumed unmodified, called with new arguments only.
- `app/helpers/application_helper.rb:852` (`other_formats_links`) — unaffected: the view
  calls it with one more link inside the existing block; the helper itself is unchanged.
- Dependents of `export_allowed?` (`timelog_controller.rb`, `gantts_controller.rb`,
  `issues_controller.rb#retrieve_previous_and_next_issue_ids`, `reports_controller.rb`) —
  unaffected: `export_allowed?` itself is not modified, only its already-computed local
  variable is read; none of these call sites are views.

## Risks / Trade-offs

- [Spec wording could drift from code again if a sibling change edits the view further] →
  Mitigation: this change's MODIFIED requirement names exact line numbers and the literal
  `f.link_to_with_query_parameters` call, so a future edit that changes them will visibly
  conflict with the spec text, prompting an update.

## Testing

Covered by the two existing `assert_select` assertions in
`test/functional/issues_controller_test.rb` (presence+href with export permission,
absence without). No new test is added by this change.
