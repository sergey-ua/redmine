# Tasks

## 1. Panel JS: close-before-navigate handlers

- [ ] 1.1 Extract a shared `isPanelOpen()` helper from the `body.quick-preview-open` check in `app/assets/javascripts/issues_quick_preview.js` and use it in the existing close-button handler; verify the existing close-button system test still passes.
- [ ] 1.2 Add a delegated `submit` handler on `#query_form` that calls `closePanel()` when `isPanelOpen()` is true and does not call `preventDefault()`; verify by submitting the form with the panel open and confirming the panel is hidden and the page navigates with the new filter applied.
- [ ] 1.3 Add a delegated `click` handler on `table.list thead th a, .pagination a` that calls `closePanel()` when `isPanelOpen()` is true and does not call `preventDefault()`; verify by clicking a sort header and a pagination link, each with the panel open, and confirming the panel is hidden and navigation proceeds unmodified in both cases.

## 2. System tests

- [ ] 2.1 Add a system test in `test/system/issues_quick_preview_test.rb`: open the preview panel, submit `#query_form` with a changed filter, assert the panel is closed and the resulting list reflects the new filter. Verify: `bundle exec rails test test/system/issues_quick_preview_test.rb`.
- [ ] 2.2 Add a system test: open the preview panel, click a sort-header link, assert the panel is closed and the resulting list is sorted as requested. Verify: same test file passes.
- [ ] 2.3 Add a system test: open the preview panel, click a pagination link, assert the panel is closed and the requested page loads. Verify: same test file passes.
- [ ] 2.4 Add a negative-case system test: with the panel already closed, submit the query form / click a sort header / click a pagination link, and assert navigation proceeds exactly as before (no error, no behavior change). Verify: same test file passes.

## 3. Verification

- [ ] 3.1 Run `bundle exec rubocop app/assets/javascripts/issues_quick_preview.js` is not applicable (JS, not Ruby) — instead manually confirm no `preventDefault()`/`stopPropagation()` was added to either new handler by reading the diff.
- [ ] 3.2 Run the full `test/system/issues_quick_preview_test.rb` suite and confirm all scenarios (open/switch/close, plus the four new navigation scenarios) pass together.
