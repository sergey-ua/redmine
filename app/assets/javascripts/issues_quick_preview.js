(function () {
  function isPanelOpen() {
    return $('body').hasClass('quick-preview-open');
  }

  function closePanel() {
    $('body').removeClass('quick-preview-open');
    $('#quick-preview-panel').removeClass('open').attr('aria-hidden', 'true');
  }

  $(document).on('click', '#quick-preview-panel [data-quick-preview-close]', function (e) {
    e.preventDefault();
    closePanel();
  });

  $(document).on('submit', '#query_form', function () {
    if (isPanelOpen()) {
      closePanel();
    }
  });

  $(document).on('click', 'table.list thead th a, .pagination a', function () {
    if (isPanelOpen()) {
      closePanel();
    }
  });
})();
