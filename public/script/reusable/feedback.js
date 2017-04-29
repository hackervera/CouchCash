var Feedback = {
  message(type, message) {
    var stateClass = type === 'error' ? 'ui-state-error' : 'ui-state-highlight';
    var iconClass = type === 'error' ? 'ui-icon-alert' : 'ui-icon-info';

    var html = '<div class="ui-widget">'
+ '<div class="' + stateClass + ' ui-corner-all" style="margin-top: 20px; padding: 0 .7em;">'
+ '  <p><span class="ui-icon ' + iconClass + '" style="float: left; margin-right: .3em;"></span>'
+ '  ' + message + '</p>' 
+ '</div>'
+ '</div>';

    return html;
  },

  info(message) {
    $('#feedback').html(Feedback.message('info', message));
    Feedback.show();
  },

  error(message) {
    $('#feedback').html(Feedback.message('error', message));
    Feedback.show();
  },

  hide() {
    $('#feedback').html('');
    $('#feedback').hide();
  },

  show() {
    $('#feedback').show();
  }
}

