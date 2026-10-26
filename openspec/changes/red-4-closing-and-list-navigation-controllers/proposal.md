# Proposal

## Why

RED-4 requires that opening, switching, and closing the issue preview panel never reload or alter the issue list (filters, sort, page, scroll position). That guarantee depends on the server-side `quick_preview` endpoint being a pure, session-isolated action. This change verifies that invariant, closes a test-coverage gap left by the direct-assertion check, and corrects a stale claim in the `controllers` spec about `authorize` being skipped for `quick_preview`.

## What Changes

- Verified (no code change): `IssuesController#quick_preview` and `ApplicationController#find_issue` never read or write `session[:issue_query]`, the sort session key (`session[sort_name]`), or `session[:per_page]`, and `quick_preview` issues no redirect.
- Add one functional test (`test/functional/issues_controller_test.rb`) that directly snapshots `session[:per_page]` and the sort session key immediately before and after a `quick_preview` call, closing a gap where existing tests only checked these indirectly through a re-rendered `index`.
- Correct the `controllers` main spec: `authorize` is **not** excluded for `quick_preview` — it runs (mapped to the `:view_issues` permission via `lib/redmine/preparation.rb:58`), contradicting the current spec text. Refresh the spec's `Source` commit line.
- No changes to `app/controllers/issues_controller.rb`, `app/controllers/application_controller.rb`, `config/routes.rb`, or `lib/redmine/preparation.rb` — the check found no production-code gap.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `controllers`: the `find_issue` runs as a `before_action` for `quick_preview` too` requirement is corrected (authorize actually runs for `quick_preview`, it is not excluded); the `quick_preview` and `find_issue` never alter the list's session state` requirement is reaffirmed with an added direct test assertion for `session[:per_page]` and the sort session key.

## Impact

- `test/functional/issues_controller_test.rb`: one new functional test, no behavior change.
- `openspec/specs/controllers/spec.md`: wording correction and `Source` refresh only, via this change's spec delta (applied on archive).
- No application code changes. The sibling change `red-4-closing-and-list-navigation-issues-preview-panel` (front-end panel JS/CSS/views) consumes the `quick_preview` endpoint's existing response shape and list-isolation behavior unchanged.

## Traceability

- Ticket: RED-4
- Domain: controllers
- Criteria: Close button leaves filters, sort, page and scroll position unchanged, no list reload; Opening, switching and closing previews never trigger a full list page reload (server-side precondition for both)
