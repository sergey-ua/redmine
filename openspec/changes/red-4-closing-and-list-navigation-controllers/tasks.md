# Tasks

## 1. Verify quick_preview is session-isolated (check only)

- [x] 1.1 Confirm `IssuesController#quick_preview` (issues_controller.rb:257) does not read/write `session[:issue_query]`, the sort session key, or `session[:per_page]`, and issues no redirect — done during exploration, no gap found.
- [x] 1.2 Confirm `ApplicationController#find_issue` (application_controller.rb:418) only sets `@issue`/`@project`, no session access — done during exploration, no gap found.
- [x] 1.3 Confirm `authorize` runs for `quick_preview` (issues_controller.rb:21-25, mapped to `:view_issues` via lib/redmine/preparation.rb:58) and is itself session-free.

## 2. Close the test-coverage gap

- [x] 2.1 In `test/functional/issues_controller_test.rb`, add a functional test that sets filters/sort/per_page via `index`, snapshots `session[:per_page]` and the sort session key (e.g. `session[:issue_sort]`) directly, calls `quick_preview`, and asserts both are byte-equal afterward.
- [x] 2.2 Run `RAILS_ENV=test bundle exec rails test test/functional/issues_controller_test.rb -n "/quick_preview/"` and confirm it passes.
- [x] 2.3 Run `bundle exec rubocop test/functional/issues_controller_test.rb` and fix any offenses in the added lines.

## 3. Correct the controllers spec (applied on archive)

- [x] 3.1 Spec delta (`specs/controllers/spec.md` in this change) corrects the "authorize excluded for quick_preview" claim to "authorize runs for quick_preview".
- [x] 3.2 Spec delta adds a scenario covering the direct session[:per_page]/sort-key assertion from task 2.1.
- [ ] 3.3 On archive, refresh the main spec's `Source` commit line to the commit that lands task 2.1's test.
