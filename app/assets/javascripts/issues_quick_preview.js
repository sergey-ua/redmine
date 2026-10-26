(function () {
  function closePanel() {
    $('body').removeClass('quick-preview-open');
    $('#quick-preview-panel').removeClass('open').attr('aria-hidden', 'true');
  }

  $(document).on('click', '#quick-preview-panel [data-quick-preview-close]', function (e) {
    e.preventDefault();
    closePanel();
  });
})();
