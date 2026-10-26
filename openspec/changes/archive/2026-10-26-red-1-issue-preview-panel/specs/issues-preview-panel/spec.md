# Spec Delta

## Purpose

Lets users inspect an issue's key fields and description from an issue list, via an AJAX side panel, without navigating away from the list.

## ADDED Requirements

### Requirement: Preview trigger on every issue-list row
Every row of the global `/issues` list and every project-scoped issue list SHALL display a "Preview" action that is visually and functionally distinct from the existing issue ID/subject link.

#### Scenario: Preview trigger present on global issue list
- **WHEN** a user views the global `/issues` list
- **THEN** each issue row shows a "Preview" action separate from the ID/subject link

#### Scenario: Preview trigger present on a project issue list
- **WHEN** a user views a project's issue list
- **THEN** each issue row shows a "Preview" action separate from the ID/subject link

### Requirement: AJAX panel open without full page reload
Clicking the "Preview" action SHALL load the preview panel via an asynchronous (AJAX) request, without triggering a full page navigation or reload.

#### Scenario: Clicking Preview does not navigate away
- **WHEN** a user clicks "Preview" on an issue row
- **THEN** the browser does not perform a full page navigation
- **AND** the panel is populated with that issue's preview content

### Requirement: Underlying list remains visible and usable while panel is open
On desktop viewports, the issue list SHALL remain visible and usable (scrollable, clickable) while the preview panel is open.

#### Scenario: List stays interactive with panel open
- **WHEN** the preview panel is open on a desktop viewport
- **THEN** the issue list underneath remains visible
- **AND** the user can still scroll and click other rows in the list

### Requirement: Panel header content
The preview panel SHALL display a header containing the issue ID, the issue subject, an "Open full issue" link to the issue's full page, and a control to close the panel.

#### Scenario: Header shows id, subject, link, and close control
- **WHEN** the preview panel is opened for an issue
- **THEN** the header shows that issue's ID and subject
- **AND** the header includes an "Open full issue" link pointing to the full issue page
- **AND** the header includes a control that closes the panel

### Requirement: Panel summary fields limited to project, tracker, status, priority, assignee
The preview panel's summary section SHALL display exactly these fields: project, tracker, status, priority, and assignee. Priority and assignee SHALL be omitted when disabled via the issue's `disabled_core_fields`, consistent with the full issue page. Category, fixed version, start/due dates, done ratio, estimated hours, and spent time are out of scope for this panel and SHALL NOT be displayed here.

#### Scenario: Summary shows the five fields
- **WHEN** the preview panel is opened for an issue with priority and assignee both enabled
- **THEN** the summary section shows the issue's project, tracker, status, priority, and assignee

#### Scenario: Assignee absent shows Unassigned
- **WHEN** the preview panel is opened for an issue with no assignee
- **THEN** the summary section shows "Unassigned" for the assignee field

#### Scenario: Disabled priority field is omitted
- **WHEN** the preview panel is opened for an issue whose tracker disables the priority core field
- **THEN** the summary section does not display a priority row

#### Scenario: Disabled assignee field is omitted
- **WHEN** the preview panel is opened for an issue whose tracker disables the assigned_to core field
- **THEN** the summary section does not display an assignee row

#### Scenario: Extended fields are not shown
- **WHEN** the preview panel is opened for any issue
- **THEN** the summary section does not display category, fixed version, start date, due date, done ratio, estimated hours, or spent time

### Requirement: Description rendering with placeholder
The preview panel SHALL render the issue's description using the same rendering used on the full issue page. When the issue has no description, the panel SHALL show a "No description" placeholder instead.

#### Scenario: Description present is rendered
- **WHEN** the preview panel is opened for an issue with a non-blank description
- **THEN** the panel shows the rendered description content

#### Scenario: Description blank shows placeholder
- **WHEN** the preview panel is opened for an issue with a blank description
- **THEN** the panel shows a "No description" placeholder

### Requirement: Server-side preview endpoint enforces full issue visibility
The server-side endpoint backing the preview panel SHALL re-check issue visibility and authorization using the same mechanism as the full issue page (`IssuesController#show`'s `find_issue`/`authorize` chain), and SHALL respect `disabled_core_fields` for the summary fields it returns.

#### Scenario: Visible issue returns preview content
- **WHEN** a user who can view a given issue requests its preview
- **THEN** the server returns the preview content for that issue

#### Scenario: Non-visible issue is rejected
- **WHEN** a user who cannot view a given issue (per `Issue#visible?`) requests its preview
- **THEN** the server does not return that issue's preview content and responds the same way `show` would for a non-visible issue

#### Scenario: Nonexistent issue is rejected
- **WHEN** a request is made for a preview of an issue id that does not exist
- **THEN** the server responds the same way `show` would for a nonexistent issue (not found), without rendering a panel

### Requirement: Out-of-scope panel features
The preview panel SHALL NOT include recent comments, a "view full history" link, handling of race conditions between rapid successive Preview clicks, keyboard/focus management, or automatic closing of the panel when the underlying list's query or filters change. These remain explicitly out of scope for this capability.

#### Scenario: No recent comments or history link shown
- **WHEN** the preview panel is opened for any issue
- **THEN** the panel does not display recent comments or a "view full history" link

#### Scenario: No defined behavior for rapid clicks, keyboard focus, or query changes
- **WHEN** a user rapidly clicks Preview on multiple rows, or uses keyboard navigation, or changes the list's filters while the panel is open
- **THEN** this capability defines no required behavior for those situations
