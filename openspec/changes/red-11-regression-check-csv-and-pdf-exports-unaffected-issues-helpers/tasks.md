# Tasks

- [x] 1. Add `test_query_to_csv_should_return_header_and_one_row_per_item` to `test/helpers/queries_helper_test.rb`: build an `IssueQuery`, call `query_to_csv(items, query)`, assert the parsed CSV's header row equals `query.columns.map { |c| c.caption.to_s }` and each data row equals `query.columns.map { |c| csv_content(c, item) }` for the corresponding item.
- [x] 2. Add `test_filename_for_export_without_query_name` to `test/helpers/queries_helper_test.rb`: with `params[:query_name]` absent and an unsaved query (`query.name` blank), assert `filename_for_export(query, 'issues')` returns `"issues"`.
- [x] 3. Add `test_filename_for_export_with_query_name_param` to `test/helpers/queries_helper_test.rb`: with `params[:query_name] = 'My Query Name'`, assert `filename_for_export(query, 'issues')` returns `"my_query_name"`.
- [x] 4. Run `RAILS_ENV=test bundle exec rails test test/helpers/queries_helper_test.rb` and confirm all three new tests (and the existing ones in the file) pass.
- [x] 5. Run `bundle exec rubocop test/helpers/queries_helper_test.rb` and fix any reported style issues.
