var dateFormat = 'yy/mm/dd',
    originalEditableValue,
    dragLock = new Lock(),
    userAgent,
    userAgentFamily;

if (navigator.userAgent.match(/iPad/i) != null) {
  userAgent = 'iPad';
  userAgentFamily = 'iOS';
} else if (navigator.userAgent.match(/iPhone/i) != null) {
  userAgent = 'iPhone';
  userAgentFamily = 'iOS';
}

$(document).ajaxError(function(e, xhr, settings, exception) {
  if (xhr.status !== 200) {
    if (settings.url.match(/update_openid/)) {
      $('#settings-feedback').html(Feedback.message('error', xhr.responseText));
    } else if (xhr.status === 401) {
      window.location = '/logout';
    } else {
      console.log('error in: ' + settings.url + ' \n' + 'error: ' + xhr.responseText);
    }
  }
});

// Correct widths and heights based on window size
function resize() {
  var height = $(window).height() - $('#global-menu').height() - 11, containerWidth = $($('ul.project-header')[0]).width(),
      width = $('.content').width() - $('.ui-icon-todo').width() - $('.ui-icon-trash').width() - 88 + 'px';

  $('.outline-view').css({ height: height + 'px' });
  $('.content').css({ height: height + 'px', width: $('body').width() - $('.outline-view').width() - $('.content-divider').width() - 1 + 'px' });
  $('.content-divider').css({ height: height + 'px' });

  if (!containerWidth) {
    containerWidth = $('.content').width();
  }

  $('.todo-items .button').each(function() {
    this.style.width = containerWidth - $($(this).prev('.state')[0]).width() - 22 + 'px';
  });
  $('.name-text').css({ width: width, 'max-width': parseInt(width, 10) - 50 });
}


function parseDate(value) {
  if (!value) return (new Date());
  return $.datepicker.parseDate(dateFormat, value, {});
}

function presentDate(value) {
  if (!value) return;
  return $.datepicker.formatDate($.datepicker.RFC_2822, $.datepicker.parseDate(dateFormat, value, {}));
}

function datePickerSave(value, element, picker) {
  var d = $.datepicker.parseDate('mm/dd/yy', value, {}),
      container;
  element.html('<span class="clear-due ui-icon ui-icon-circle-close"> </span>'
               + '<span class="due-button">' + $.datepicker.formatDate($.datepicker.RFC_2822, d) + '</span>');
  $(picker).remove();

  // Save
  container = element.closest('li.task');
  if (container.length > 0) {
    Task.find(container.itemID()).set('due', $.datepicker.formatDate(dateFormat, d));
  } else {
    Project.find(selectedProject()).set('due', $.datepicker.formatDate(dateFormat, d));
  }
}

function escapeQuotes(text) {
  return text ? text.replace(/"/g, '&quot;') : text;
}

$(function(){

  $(window).resize(function() {
    setTimeout(resize, 100);
  });

  $(window).focus(resize);

  // Sections

  $('.named-collection').click(function() {
    if (dragLock.locked) return;

    $('.outline-view .selected').removeClass('selected');
    $(this).closest('li').addClass('selected');    

  });
  
  function showLoader() {
    $('.project-header').html(Mustache.to_html($('#loader').html(), {}));
  }
  
  function hideLoader() {
    $('.project-header').html('')
  }

  $('#overview').click(function(){
    showLoader();
    $.getJSON('/balance', function(data) {
      hideLoader();
      $.each(data, function(person,amount) {        
        if (amount < 0) {
          showCredit({person: person, amount: amount});
        } else {
          showDebt({person: person, amount: amount});
        }
      })
    })
  })
    
  function showDebt(data) {
    $('.project-header').append(Mustache.to_html($('#debt-template').html(), data));
  }
  
  function showCredit(data) {
    $('.project-header').append(Mustache.to_html($('#credit-template').html(), data));
  }
  
  if (userAgentFamily != 'iOS') {
    $('.editable .field').live('blur', function(e) {
      saveEditable();
      closeEditable();
    });
  }

  if (userAgentFamily !== 'iOS') {  
    $('.content').live('click', function(e) {
      if ($(e.target).hasClass('content')) {
        TasksController.closeEditors();
        $('.todo-items .highlight').removeClass('highlight');
      }
    });
  }

  // Modal login panel
  $('#login-dialog').dialog({
    autoOpen: true,
    title: 'Please Login',
    width: 400,
    modal: true,
    resizable: false,
    open: function(event, ui) { $(".ui-dialog-titlebar-close").hide(); },
    closeOnEscape: false,
    beforeclose: function() { return false; }    
  });
  $('#login-button').button({ });

  $('#login-button').click(function(){
    $('#login-form').submit();
  })
  
  $('#login-form').submit(function(e) {
    window.location = "/login?openid=http://google.com/profiles/" + $('#openid_url').val();
    e.preventDefault();
  });
  $('#openid_url').select();

  // Resize when the dialog opens/closes else it sometimes messes up the scrollbars
  $('#delete-project-button').click(function(e) {
    $('#delete-project-dialog').dialog('open');
    resize();
    e.preventDefault();
    return false;
  });

  $('#export-text-button').click(function(e) {
    $('#export-text-dialog').dialog('open');
    var input = $('#export-text-value'),
        project = Project.find(selectedProject()),
        tasks = ProjectsController.tasks(project),
        output = '',
        done;

    for (var i in tasks) {
      done = tasks[i].get('done') ? '✓ ' : '◻ ';
      output += done + tasks[i].get('name') + '\n';
    }
    input.html(output);
    e.preventDefault();
  });

  $(document).bind('dialogclose', function(event, ui) {
    resize();
  });

  $('.state').live('mouseenter', function() { $(this).addClass('ui-state-hover'); }); 
  $('.state').live('mouseleave', function() { $(this).removeClass('ui-state-hover'); });

  $('.delete').live('mouseenter', function() { $(this).addClass('ui-state-hover'); }); 
  $('.delete').live('mouseleave', function() { $(this).removeClass('ui-state-hover'); });

  $('.outline-view ul.items li').live('mouseenter', function() {
    $(this).addClass('hover');
  });

  $('.outline-view ul.items li').live('mouseleave', function() {
    $(this).removeClass('hover');
  });

  // Resizable panes
  (function() {
    var moving = false, width = 0;

    function start() {
      moving = true;
    }

    function end() {
      if (width > 0) {
        Settings.set('outline-view-width', width);
      }
      moving = false;
    }

    function move(e) {
      if (moving) {
        $('.outline-view').css({ width: e.pageX });
        width = e.pageX;
        resize();
      }
    }

    $('.content-divider').bind('mousedown', start);
    $(document).bind('mousemove', move);
    $(document).bind('mouseup', end);
  })();

  $('#send-money-dialog').dialog({
    autoOpen: false,
    width: 600,
    buttons: {
     'OK': function(e) { 
       $(e.target).text("Sending payment...")
       var dialog = $(this);
       showLoader();
        $.post('/owe', {wfid: $('#webfinger').val(), amount: $('#value').val()}, function(data) {
          dialog.dialog('close'); 
          $.get('/validate', function(){
            hideLoader();
            $('#overview').click();            
          })
        });
        
      }, 
    },
    modal: true
  });
  
  $('.add-button').click(function(e) {
    $('#send-money-dialog').dialog('open');
  });

  // Setup

  $('.add-button').button({ icons: { primary: 'ui-icon-circle-arrow-e' } });
  $('#logout').button({ icons: { primary: 'ui-icon-power' } }).click(function(){ window.location = '/logout'; });

  // disableTextSelect works better than disableSelection
  $('.content-divider').disableTextSelect();

  $('label').inFieldLabels();  
  resize();
  $('#overview').click();
});