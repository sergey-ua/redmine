# Tasks

## 1. Routing and controller

- [ ] 1.1 Add `get 'quick_preview', :as => 'quick_preview'` to the `member do ... end` block on `resources :issues` in `config/routes.rb`, verifying it does not collide with the existing `preview_issue` route (run `bin/rails routes | grep quick_preview` and confirm `preview_issue` is unchanged).
- [ ] 1.2 Add `IssuesController#quick_preview` action, add `quick_preview` to the `find_issue` `before_action :only => [...]` list, and confirm `authorize`'s `:except` list is left untouched; verify with a functional test that an anonymous/unauthorized user hitting `quick_preview` on an issue they cannot view gets the same rejection as `show`.
- [ ] 1.3 Have `quick_preview` respond only via `.js.erb` format, matching the existing Redmine AJAX idiom; verify with a functional test asserting a successful `xhr: true` request renders the `quick_preview.js.erb` template.

## 2. Panel partial, view, and locale keys

- [ ] 2.1 Add `app/views/issues/_quick_preview.html.erb` rendering: header (issue id, subject, "Open full issue" link via `issue_path`, close control), summary (project, tracker, status always shown, priority and assigned_to guarded by `@issue.disabled_core_fields.include?(...)` exactly as in `show.html.erb`), and description (`textilizable` when `@issue.description?`, else "No description" placeholder). Verify by rendering the partial in a functional test for an issue with and without a description.
- [ ] 2.2 Add `app/views/issues/quick_preview.js.erb` that injects the rendered partial into the panel container and reveals it; verify by asserting the `.js.erb` response body references the panel container id and the escaped partial HTML.
- [ ] 2.3 Add new locale keys to `config/locales/en.yml` for "Unassigned" (assignee placeholder), "No description" (description placeholder), "Preview" (row trigger label), and "Open full issue" (header link label); verify with `grep` that each key is present and used via `l(:key)` in the partial/view (no hardcoded English strings).
- [ ] 2.4 Verify assignee-nil renders "Unassigned" (not show.html.erb's "-") with a functional/unit test asserting the rendered partial for an unassigned issue contains "Unassigned".
- [ ] 2.5 Verify disabled-core-field guards: functional tests asserting that when `disabled_core_fields` includes `priority_id` the panel omits the priority row, and likewise for `assigned_to_id`.
- [ ] 2.6 Verify out-of-scope exclusions: a functional/unit test asserting the rendered partial never includes category, fixed_version, start/due dates, done_ratio, estimated_hours, spent time, recent comments, or a "view full history" link.

## 3. Issue list trigger and panel container

- [ ] 3.1 Add the "Preview" trigger link to `app/views/issues/_list.html.erb`'s existing `<td class="buttons hide-when-print">` cell (alongside `link_to_context_menu`), using `remote: true` and pointing at the `quick_preview_issue_path`; verify by rendering the issues index in an integration test and asserting each row contains both the ID/subject link and a distinct Preview link.
- [ ] 3.2 Add the initially empty/hidden panel container markup once to `app/views/issues/index.html.erb` (confirmed shared by global and per-project lists); verify by requesting both `/issues` and a project's issues index and asserting the container markup appears exactly once in each response.

## 4. Panel behavior (JS/CSS)

- [ ] 4.1 Add new JS (included directly from `index.html.erb`, not via `ApplicationHelper#javascript_heads`) to open the panel on the Preview link's AJAX success and wire the header's close control to hide it; verify by confirming the script is only requested on the issues index page (not on an unrelated page) and that `ApplicationHelper#javascript_heads` is unmodified (`git diff` shows no change to that helper).
- [ ] 4.2 Add new CSS for the panel's layout so the underlying list remains visible and usable (scrollable/clickable) on desktop while the panel is open; verify with a system/integration test (Capybara, per the redmine-workbench skill) that after clicking Preview, a row in the list outside the panel remains clickable and the page did not perform a full navigation.
- [ ] 4.3 Run `npx stylelint "app/assets/stylesheets/**/*.css"` against the new CSS and `bundle exec rubocop` against the new/changed Ruby files, fixing any reported issues.

## 5. Out-of-scope confirmation

- [ ] 5.1 Confirm in review (no code change) that recent comments, "view full history" link, rapid-click race handling, keyboard/focus handling, and auto-close on query/filter change are not implemented, matching the spec's explicit out-of-scope requirement; verify by checking the diff introduces no code paths for these behaviors.
