# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative '../application_system_test_case'

class IssuesQuickPreviewSystemTest < ApplicationSystemTestCase
  def test_preview_opens_panel_and_leaves_list_usable
    log_user('jsmith', 'jsmith')
    visit '/issues'
    page.execute_script('window.quickPreviewNoReloadMarker = true')

    first('tr.issue td.buttons a.quick-preview-trigger').click
    assert_selector '#quick-preview-panel.open', wait: 5
    assert_selector '#quick-preview-panel-body .quick-preview-header'
    assert page.evaluate_script('window.quickPreviewNoReloadMarker'), 'page was reloaded'

    link = all('tr.issue td.subject a', minimum: 2).first
    link.scroll_to(:center)
    assert link.visible?
    overlaps = page.evaluate_script(
      "(function(el){ var p = document.getElementById('quick-preview-panel').getBoundingClientRect();" \
      " var r = el.getBoundingClientRect(); return r.right > p.left && r.left < p.right && r.bottom > p.top && r.top < p.bottom; })(arguments[0])",
      link.native
    )
    assert_not overlaps, 'list link overlaps the open panel'
  end

  def test_preview_close_hides_panel
    log_user('jsmith', 'jsmith')
    visit '/issues'

    first('tr.issue td.buttons a.quick-preview-trigger').click
    assert_selector '#quick-preview-panel.open', wait: 5
    find('#quick-preview-panel [data-quick-preview-close]').click
    assert_no_selector '#quick-preview-panel.open'
  end

  def test_submitting_query_form_closes_panel_and_applies_filter
    log_user('jsmith', 'jsmith')
    visit '/issues'

    first('tr.issue td.buttons a.quick-preview-trigger').click
    assert_selector '#quick-preview-panel.open', wait: 5

    page.execute_script("document.getElementById('query_form').submit()")
    assert_no_selector '#quick-preview-panel.open', wait: 5
    assert_selector 'table.list'
  end

  def test_clicking_sort_header_closes_panel_and_sorts_list
    log_user('jsmith', 'jsmith')
    visit '/issues'

    first('tr.issue td.buttons a.quick-preview-trigger').click
    assert_selector '#quick-preview-panel.open', wait: 5

    find('table.list thead th a', text: /\AStatus\z/).click
    assert_no_selector '#quick-preview-panel.open', wait: 5
    assert_match(/sort=status/, page.current_url)
  end

  def test_clicking_pagination_link_closes_panel_and_loads_page
    project = Project.find(1)
    26.times { Issue.generate!(project: project, tracker: project.trackers.first, author: User.find(2)) }
    log_user('jsmith', 'jsmith')
    visit '/issues?per_page=25'

    first('tr.issue td.buttons a.quick-preview-trigger').click
    assert_selector '#quick-preview-panel.open', wait: 5

    find('.pagination a', text: /\A2\z|Next/, match: :first).click
    assert_no_selector '#quick-preview-panel.open', wait: 5
    assert_match(/page=2/, page.current_url)
  end

  def test_navigation_with_panel_closed_is_unchanged
    log_user('jsmith', 'jsmith')
    visit '/issues'
    assert_no_selector '#quick-preview-panel.open'

    find('table.list thead th a', text: /\AStatus\z/).click
    assert_match(/sort=status/, page.current_url)
    assert_no_selector '#quick-preview-panel.open'
  end
end
