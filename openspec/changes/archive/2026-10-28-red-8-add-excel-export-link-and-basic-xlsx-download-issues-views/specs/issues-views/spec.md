# Spec Delta

## MODIFIED Requirements

### Requirement: The other-formats block offers CSV, PDF and Atom links, gated by `export_allowed`
The system SHALL compute `export_allowed = export_allowed?(:export_issues, @query.base_scope)` once (index.html.erb:37) and render, inside `other_formats_links` (lib/redmine/views/other_formats_builder.rb), a 'CSV' link (opens a modal, `index.html.erb:39`), a 'PDF' link (direct, `:40`), and an 'Excel' link (direct, `:41`, `f.link_to_with_query_parameters 'Excel', {:format => 'xlsx'}, :class => 'xlsx'`) only when `export_allowed` is true, and an 'Atom' link (`:42`) unconditionally regardless of `export_allowed`. The 'Excel' link targets the `.xlsx` format of `IssuesController#index` and opens no modal (unlike CSV, which opens a configuration dialog): clicking it downloads the file immediately. The `:format => 'xlsx'` and `:class => 'xlsx'` options override `link_to_with_query_parameters`'s name-derived defaults (which would otherwise use `'excel'`).

#### Scenario: User without export permission sees Atom but not CSV/PDF
- **WHEN** `export_allowed` is false for the current user
- **THEN** the other-formats block renders only the 'Atom' link; the 'CSV', 'PDF' and 'Excel' links are not rendered

#### Scenario: User with export permission sees CSV, PDF and Atom together
- **WHEN** `export_allowed` is true
- **THEN** the other-formats block renders 'CSV', 'PDF', 'Excel' and 'Atom' in that order (index.html.erb:39-42); 'Excel' is a direct download link like 'PDF', not a modal-opening link like 'CSV'
