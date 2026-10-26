# Spec Delta

## MODIFIED Requirements

### Requirement: `find_issue` runs as a `before_action` for `quick_preview` too
The system SHALL run `find_issue` as a `before_action` for `quick_preview` (in addition to `show`, `edit`, `update`, `issue_tab`), and SHALL also run `authorize` for it — `quick_preview` is not in the `authorize` before_action's `:except` list (`:only => [:index, :new, :create]`-equivalent exclusion does not apply to it), so visibility is enforced both by `find_issue`'s `raise Unauthorized unless @issue.visible?` and by `authorize`'s permission check, mapped to the `:view_issues` permission via `lib/redmine/preparation.rb:58`.

#### Scenario: quick_preview enforces the same visibility check as show
- **WHEN** a user requests `quick_preview` for an issue they cannot see, or for an issue id that does not exist
- **THEN** the controller responds the same way `show` would: `Unauthorized`/`deny_access` (403) for a non-visible issue, or `render_404` for a missing one

### Requirement: `quick_preview` and `find_issue` never alter the list's session state
`quick_preview` (`app/controllers/issues_controller.rb:257`) SHALL only set `@issue`/`@project` (via `find_issue`) and render a JS partial; it SHALL NOT read or write `session[:issue_query]` (or any other `<klass>_query` session key), the sort session key written by `sort_helper.rb`, or `session[:per_page]`. Those session keys are written only by `retrieve_query` (`app/helpers/queries_helper.rb:352`, invoked from `index`-style list actions) and the sort/pagination helpers invoked alongside it. `find_issue` (`app/controllers/application_controller.rb:418`) sets only `@issue` and `@project` and performs no session access.

#### Scenario: Opening, switching, or closing a preview leaves the list query state unchanged
- **WHEN** a user has a list open with filters, sort, and pagination set (stored in `session[:issue_query]` and related session keys) and then requests `quick_preview` for an issue (opening, or switching to, a preview)
- **THEN** `session[:issue_query]` and the sort/pagination session state are byte-for-byte unchanged after the request
- **AND** a subsequent re-render of the list (`index`) reflects the same filters, sort, and pagination as before the preview request

#### Scenario: Sort and per-page session keys are unaffected directly, not just via the re-rendered list
- **WHEN** a user has a list open with sort and `per_page` set (stored in the sort session key and `session[:per_page]`) and then requests `quick_preview` for an issue
- **THEN** the sort session key and `session[:per_page]` are unchanged, checked directly on the session immediately before and after the `quick_preview` request, not only inferred from a subsequent `index` render
