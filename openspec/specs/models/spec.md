# models Specification

## Purpose
`app/models` holds Redmine's domain objects. `Issue` and `Journal` implement the visibility rules that every controller and view must respect before showing issue data or history to a user.

## Requirements

### Requirement: Issue visibility is permission- and project/tracker-scoped
The system SHALL compute `Issue#visible?(usr=nil)` (`app/models/issue.rb:181`) from the given or current user's `:view_issues` permission on the issue's project, combined with the role's `issues_visibility` setting (`all`, `default`, `own`) and, for private issues, whether the user is the author or assignee. When the role does not have `:view_issues` on all trackers, the tracker must also be in the role's allowed tracker list (`permissions_tracker_ids?`).

#### Scenario: Private issue author/assignee exception
- **WHEN** a logged-in user has `issues_visibility == 'default'` and the issue is private
- **THEN** `visible?` is true only if that user is the issue's author or is/belongs to the assigned_to, otherwise false.

#### Scenario: Anonymous user and private issues
- **WHEN** the user is not logged in (anonymous)
- **THEN** `visible?` is true only if the issue is not private (and the anonymous role has `:view_issues`).

### Requirement: Journal visibility follows its issue
The system SHALL delegate `Journal#visible?` (`app/models/journal.rb:165`) to `journalized.visible?` (the parent issue's `visible?`), so a journal/note is only visible when its issue is.

#### Scenario: Journal on a now-invisible issue
- **WHEN** `Issue#visible_journals_with_index` (`app/models/issue.rb:934`) builds the list of journals to show (used by `IssuesController#show` for `@journals`)
- **THEN** it filters to journals whose `visible?` is true, which in turn means their `journalized` issue is visible to the current user.

### Requirement: Per-tracker field visibility
The system SHALL expose `Issue#disabled_core_fields` (`app/models/issue.rb:660`), delegating to `tracker.disabled_core_fields`, as the list of core field names (e.g. `priority_id`, `assigned_to_id`, `category_id`, `fixed_version_id`, `start_date`, `due_date`, `done_ratio`, `estimated_hours`) that the issue's tracker hides, independent of permissions.

#### Scenario: Field disabled by tracker settings
- **WHEN** a field name is present in `disabled_core_fields`
- **THEN** any view or endpoint rendering issue summary fields must omit that field, matching what `show.html.erb` already does with `unless @issue.disabled_core_fields.include?(...)`.

## Code map
- app/models/issue.rb: `visible?` (line 181), `disabled_core_fields` (line 660), `visible_journals_with_index` (line 934).
- app/models/journal.rb: `visible?` (line 165, delegates to `journalized.visible?`).
- Entry points: `Issue#visible?` (app/models/issue.rb:181), `Issue#visible_journals_with_index` (app/models/issue.rb:934), `Journal#visible?` (app/models/journal.rb:165).
- Depends on this area: dozens of call sites in app/models/issue_query.rb, app/models/changeset.rb, app/models/group.rb, app/models/project.rb, app/models/user.rb, app/models/wiki_page.rb, app/models/mail_handler.rb, app/models/repository/git.rb (see Graph queries below) — all are other model-layer consumers of `Issue`/`Journal`, not part of this ticket's area; none are controllers or views, which the graph does not link to models (Ruby method calls on instance variables are not resolved as edges).

Source: commit 53abb0a6c4107c996ee4d478e1f50441f6328912
Graph queries: god-nodes areas/models: Issue (216 edges), User (126), Project (122), Journal (51) — all in Code map/Purpose; affected Issue --depth 2: 36 dependents, all within app/models (e.g. app/models/issue_query.rb:315, app/models/changeset.rb:215) — confirms no direct controller/view edge exists; affected Journal --depth 2: 36 dependents, all within app/models (e.g. app/models/issue.rb:892 `init_journal`, app/models/issue.rb:953 `visible_journals_with_index`) — confirms the Issue/Journal relationship from the model side; affected visible_journals_with_index --depth 2: no affected nodes (leaf method, nothing in the graph calls it onward within depth 2 — consistent with it being called from the controller, an edge the graph does not capture).
