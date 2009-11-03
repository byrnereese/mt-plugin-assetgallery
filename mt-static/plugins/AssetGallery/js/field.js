$(document).ready( function() {
    $(document).keyup(function(event){
	if (event.keyCode == 27) {
	  $('li.expanded .gallery-asset .editform input').each( function() {
              $(this).val($(this).attr('mt:original'));
	      $(this).parent().hide();
              $(this).parent().parent().find('.display').show();
	      $(this).parent().parent().parent().removeClass('expanded');
          });
	}
    });
    $('#entry_form').submit( function() {
	$('.gallery-asset .editform input').each( function() {
	    if ($(this).val() == $(this).attr('title')) {
	      $(this).val('');
	    }
        });
        return true;
    });
    $('a.remove-asset').click( function() {
        var id = $(this).attr('mt:asset_id');
        $('li#asset-'+id).fadeOut('fast',function() { 
            var p = $(this).parent().attr('mt:field_id');
	    $(this).remove();
	    var ids = $('#'+p).val().split(',');
	    ids = $.grep(ids, function(val) { return val != id; });
	    $('#'+p).val(ids.join(','));
        });
        return false;
    });
    $('a.edit-asset').click( function() {
        var id = $(this).attr('mt:asset_id');
        $('li#asset-'+id+' .gallery-asset .editform input').each(function() {
	    $(this).attr('mt:original',$(this).val());
        });
        $('li#asset-'+id+' .gallery-asset .editform').show();
        $('li#asset-'+id+' .gallery-asset .display').hide();
        $(this).parent().parent().addClass('expanded');
        return false;
    });
    $('.gallery-actions button').click( function(event) {
	event.stopPropagation();
	showDisplay( $(this).parent().parent().find('.editform') );
        return false;
    });
    $('.gallery-asset .editform input').each( function() {
	if ($(this).val() == '') {
          $(this).val( $(this).attr('title') );
          $(this).addClass('default');
        }
    });
    function showDisplay( e ) {
      e.find('input').each( function() {
	  $(this).trigger('blur');
	  $(this).unbind('keypress');
	});
      var l = e.find('.label').val();
      var d = e.find('.caption').val();
      e.parent().find('.display .label').html(l);
      e.parent().find('.display .caption').html(d);
      e.hide().parent().find('.display').show();
      e.parent().parent().removeClass('expanded');
    };
    $('.gallery-asset .editform input').focus( function() {
        var e = $(this);
	if (e.val() == $(this).attr('title')) {
          e.val('');
          e.removeClass('default');
        }
	e.bind('keypress', function(event) {
          if (event.keyCode == 13) {
            event.stopPropagation();
            showDisplay( e.parent() );
	    /*
	    e.trigger('blur');
            var l = e.parent().find('.label').val();
            var d = e.parent().find('.caption').val();
            e.parent().parent().find('.display .label').html(l);
            e.parent().parent().find('.display .caption').html(d);
            e.parent().hide().parent().find('.display').show();
            e.parent().parent().parent().removeClass('expanded');
            e.unbind('keypress');
	    */
	    return false;
          }
	});
    });
    $('.gallery-asset .editform input').blur( function() {
	if ($(this).val() == '') {
          $(this).val( $(this).attr('title') );
          $(this).addClass('default');
        }
	$(this).unbind('keypress');
    });
});

function galleryView(id, view) {
  var viewFields, editFields, origValue;
  if(view == true) { // Cancel Editing
    viewFields = 'block';
    editFields = 'none';
  } else {
    viewFields = 'none';
    editFields = 'block';
  }            
  
  $(id + '_listing').style.display = editFields;
  $(id + '_cancel_button').style.display = editFields;
  $(id + '_delete_button').style.display = editFields;
  $(id + '_edit_button').style.display = viewFields;
  
  if(view == true) { // Cancel Editing - reset everything
    eval("origValue = " + id + "origValue");
    $(id).value = origValue;
    
    var trs = document.getElementById(id + '-listing').getElementsByTagName('tr');
    for (var i = 0; i < trs.length; i++) 
      trs[i].style.display = 'table-row';
  }            
}

function deleteAssets(id) {
  var inputs, ids = new Array();
  inputs = document.getElementById(id + '-listing').getElementsByClassName('select');
  for (var i = 0; i < inputs.length; i++) {
    var cbx = inputs[i];
    
    if(cbx.checked == true) {
      document.getElementById('asset-' + cbx.value).style.display = 'none';
    } else {
      ids.push(cbx.value);
    } 
    
  }
  document.getElementById(id).value = ids.join(',');
}
