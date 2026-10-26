# Design

## Context

See proposal.md - Why. Redmine already uses a `remote: true` + `<action>.js.erb` AJAX idiom extensively (e.g. `issue_tab`, context menu). `IssuesController#show` is the reference implementation for issue visibility: `find_issue` (before_action) loads `@issue` and 404s/redirects when not found or not visible; `authorize` (before_action) enforces permission on the action. `Issue#disabled_core_fields` governs which core fields a tracker has disabled; `show.html.erb` guards `priority_id` and `assigned_to_id` rows with it but does not guard `status` (status is always shown). `app/views/issues/_list.html.erb`'s per-row `<td class="buttons hide-when-print">` already holds one action (`link_to_context_menu`) and is the natural home for a second row-level action. `app/views/issues/index.html.erb` is shared by the global and per-project issue lists (confirmed, no separate per-project action), so the panel container is added there exactly once.

## Goals / Non-Goals

**Goals:**
- Add a `quick_preview` action/route/view set that mirrors `show`'s visibility/authorization behavior for exactly five summary fields plus description.
- Keep the panel's existence to the issues index page: no changes to globally-loaded JS/CSS helpers.
- Reuse the existing `disabled_core_fields` guard idiom rather than introducing a new abstraction.

**Non-Goals:**
- Recent comments, "view full history" link, keyboard/focus management, race-condition handling for rapid clicks, auto-close on filter/query change (see proposal.md - explicitly out of scope; tracked only as a spec note, not designed here).
- Any change to `show.html.erb`'s own rendering, `IssuesHelper#issue_fields_rows`, `ApplicationHelper#link_to_issue`, or `ApplicationHelper#javascript_heads`.
- Mobile-specific layout guarantees (ticket scope is "desktop" for list-stays-usable behavior).

## Decisions

- **New action name `quick_preview`, not `preview`.** Redmine already defines `match '/issues/preview' ... :as => 'preview_issue'` for the unrelated text-preview (Textile/Markdown render-as-you-type) feature in `previews#issue`. Reusing `preview` as an action name on `IssuesController` or `preview` as a route helper would collide with `preview_issue_path`/`preview_issue_url`. `quick_preview` keeps both the action name and generated route helper (`quick_preview_issue_path`) unambiguous.
- **Route placed as a member route on `resources :issues`.** Mirrors the existing `tab/:name` member route; a member route naturally resolves to `/issues/:id/quick_preview`, giving `find_issue` the `:id` param it expects, exactly like `show`.
- **`quick_preview` added to `find_issue`'s `:only` list, left out of `authorize`'s `:except` list.** This is the minimum change that gives the new action the same visibility gate as `show` while still requiring the same permission check `show` requires (`:view_issues`), so a user who cannot view an issue gets the same rejection as if they had hit `show` directly.
- **Partial does not reuse `IssuesHelper#issue_fields_rows`.** That helper renders a two-column "rows" table built for the full issue page's larger field set (left/right column layout). The panel only ever shows 5 fields in a simple vertical list, so a plain `content_tag`/`safe_join` structure in the new partial is simpler and avoids coupling the panel's layout to a helper designed for a different visual layout. The `disabled_core_fields` *conditionals* are copied verbatim from `show.html.erb`, not the helper call itself.
- **Assignee-nil renders "Unassigned", diverging intentionally from `show.html.erb`'s "-".** The ticket explicitly specifies "Unassigned" for the panel; `show.html.erb`'s "-" convention is left untouched since it's out of this change's scope.
- **JS is included directly from `index.html.erb`, not through `ApplicationHelper#javascript_heads`.** `javascript_heads` is included on every page; the preview panel only exists on the issues index view, so adding the script there (via a page-scoped `javascript_include_tag` or a `content_for` block already supported by the layout) avoids loading unused JS elsewhere and avoids touching a shared helper used by all controllers.
- **Response format is `.js.erb`, not JSON.** Matches decision Q2 (reuse Rails-UJS `remote: true` + `.js.erb`, not a custom fetch()/JSON module) and Redmine's existing idiom elsewhere in the codebase.

## Risks / Trade-offs

- [Risk] A new partial duplicating field-guard logic from `show.html.erb` can drift out of sync if `disabled_core_fields` semantics change. → Mitigation: functional tests assert the same guard behavior for both `show` and `quick_preview`; keep the guard conditionals textually close to `show.html.erb`'s to ease future side-by-side review.
- [Risk] Page-scoped JS/CSS (not global) could be missed by a future refactor that assumes all page JS lives in `javascript_heads`. → Mitigation: note the deliberate exception in code comments near the `index.html.erb` include.
- [Risk] Keeping `authorize` active for `quick_preview` without a dedicated permission could tie the preview too tightly to `:view_issues`; if a future requirement needs a different permission, this will need revisiting. → Accepted for this change since the ticket explicitly wants the same visibility semantics as `show`.

## Traceability

Ticket: RED-1
Domain: issue list preview
Criteria: C1, C9
