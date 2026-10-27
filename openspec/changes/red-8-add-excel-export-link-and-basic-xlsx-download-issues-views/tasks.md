# Tasks

## 1. Excel link in the other-formats block

- [x] 1.1 Add `f.link_to_with_query_parameters 'Excel', {:format => 'xlsx'}, :class => 'xlsx'` inside the `if export_allowed` branch of `app/views/issues/index.html.erb` (lines 37-44), between 'PDF' and 'Atom'. Verify: reading `index.html.erb` shows the line present (already committed as part of commit 77e0ed4b2 on `factory/RED-8`).
- [x] 1.2 Add `assert_select 'a.xlsx[href="/issues.xlsx"]'` to the functional test covering a user with export permission, and `assert_select 'p.other-formats a.xlsx', 0` to the test covering a user without it, in `test/functional/issues_controller_test.rb`. Verify: `bundle exec rails test test/functional/issues_controller_test.rb` passes both assertions (already present at lines 743 and 835).

## 2. Spec documentation

- [x] 2.1 Rewrite the "other-formats block" requirement in `openspec/specs/issues-views/spec.md` from forward-looking language about a future Excel link to a factual description of the Excel link that now exists, with both scenarios updated to include it. Verify: `openspec validate red-8-add-excel-export-link-and-basic-xlsx-download-issues-views` reports no errors.
