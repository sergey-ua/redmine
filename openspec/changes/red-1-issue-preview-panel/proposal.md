# Proposal

## Why

Users browsing the global `/issues` list or a project's issue list currently must open the full issue page (a full page navigation) just to check an issue's status, assignee, priority, or description before deciding whether it's the one they want. A lightweight "Preview" action that AJAX-loads a side panel next to the list lets users inspect an issue's key fields and description without losing their place in the list, reducing round trips for simple look-ups.

## What Changes

- Add a "Preview" trigger link on every issue-list row (`app/views/issues/_list.html.erb`), in the existing `<td class="buttons hide-when-print">` cell, alongside `link_to_context_menu`. Distinct from the existing ID/subject link; uses Rails-UJS `remote: true`.
- Add a new controller action `IssuesController#quick_preview` that is added to the `find_issue` `before_action` list (alongside `show`, `edit`, `update`, `issue_tab`) so it gets the identical visibility check (`Issue#visible?` via `find_issue`), and remains covered by the existing `authorize` `before_action` (not added to its `:except` list). Responds only to `.js.erb` (AJAX), matching Redmine's existing `remote: true` + `.js.erb` idiom (same pattern used elsewhere in the app, e.g. issue_tab).
- Add a new route for this action as a member route on `resources :issues` (`config/routes.rb`, inside the existing `member do ... end` block alongside `edit`/`tab`), using a path/name that does not collide with the existing `/issues/preview` (`preview_issue`) text-preview route, e.g. `get 'quick_preview', :as => 'quick_preview'`.
- Add a new partial, e.g. `app/views/issues/_quick_preview.html.erb`, rendering the panel body: header (issue id, subject, "Open full issue" link to `issue_path`/`issue_url`, close control), summary (project, tracker, status, priority, assignee-or-"Unassigned"), and rendered description (or "No description" placeholder). Priority and assigned_to rows are guarded by the same `@issue.disabled_core_fields.include?(...)` conditionals used in `show.html.erb`; status is rendered unconditionally (matching `show.html.erb`, which has no guard for status). Project and tracker have no existing guard in `show.html.erb` either and are rendered unconditionally.
- Add a `.js.erb` view (e.g. `app/views/issues/quick_preview.js.erb`) that injects the rendered partial's HTML into the panel container and reveals it, following the existing Redmine AJAX response idiom.
- Add the (initially empty/hidden) panel container markup once in `app/views/issues/index.html.erb` (confirmed: `IssuesController#index` serves both the global and per-project issue lists, so no duplication is needed).
- Add new JS to open/close the panel and keep the underlying list visible/usable while it is open (desktop); include it directly from `index.html.erb` via a scoped `javascript_include_tag`/inline script rather than registering it in the global `ApplicationHelper#javascript_heads`, since the panel only exists on the issues index page.
- Add new CSS for the panel's layout (side panel positioning, visibility toggling, responsive/desktop behavior).
- Add new locale keys to `config/locales/en.yml` for: "Unassigned" assignee placeholder, "No description" placeholder, "Preview" button/link label, and "Open full issue" link label (confirmed via search: none of these currently exist).
- Explicitly out of scope for this change (noted in the spec, not designed or implemented): recent comments (up to 5), "View full history" link, race-condition handling between rapid Preview clicks, keyboard/focus handling, and closing the panel automatically on list query/filter change.

## Capabilities

### New Capabilities
- `issues-preview-panel`: Defines the issue-list row "Preview" trigger, the AJAX side panel UI (header, summary fields, description), and the server-side preview endpoint's visibility/authorization behavior.

### Modified Capabilities
(none — `issues-views` and `issues-helpers` are not having their documented requirements changed; see "Also Affected" in design.md for why each related file/helper is unaffected.)

## Impact

- **Controller**: `app/controllers/issues_controller.rb` — new `quick_preview` action; `find_issue`'s `:only` list gains `quick_preview`; `authorize`'s `:except` list is untouched (so `quick_preview` stays authorized).
- **Routes**: `config/routes.rb` — new member route on `resources :issues`, distinct from the existing `preview_issue` route.
- **Views**: new partial `app/views/issues/_quick_preview.html.erb`, new `app/views/issues/quick_preview.js.erb`, edits to `app/views/issues/_list.html.erb` (trigger link) and `app/views/issues/index.html.erb` (panel container + JS include).
- **Locales**: `config/locales/en.yml` — new keys for "Unassigned", "No description", "Preview", "Open full issue".
- **JS/CSS**: new JS file for panel open/close behavior; new CSS for panel layout, both included only from the issues index page.
- **Tests**: new functional test coverage for `IssuesController#quick_preview` (visible issue, non-visible issue, nonexistent issue, `disabled_core_fields` guard for priority/assignee); a system/integration test note for the AJAX open behavior and "list stays visible and usable" requirement.
- **Unaffected** (verified by direct reads): `IssuesHelper#issue_list`/`grouped_issue_list`, `ApplicationHelper#link_to_issue`, `IssuesHelper#issue_fields_rows` (pattern reused, helper itself not called), `ApplicationHelper#javascript_heads` (not modified; JS included directly from index.html.erb instead), `ApplicationController#find_issue`/`#authorize`, `Issue#visible?`, `Issue#disabled_core_fields`.

## Traceability

Ticket: RED-1
Domain: issue list preview
Criteria: C1, C9
