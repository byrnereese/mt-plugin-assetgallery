	// Use initCallback to assign control funcitonality to the carousel
	function slideshow_initCallback(carousel) {
		// Use the specified next/prev buttons for the carousel
		    $('#carousel-next').bind('click', function() {
		        carousel.next();
		        return false;
		    });
		    $('#carousel-previous').bind('click', function() {
		        carousel.prev();
		        return false;
		    });
	}

$(document).ready( function() {
    $('.gallery-item').bind('slidechange', function( event, idx ) {
	$('.ad-placement iframe').each( function() {
	    var ord = Math.random()*10000000000000000;
	    var isrc = $(this).attr("src").replace(/ord=.*$/,'ord='+ord+'?');
	    $(this).attr( "src", isrc );
	    s.prop37= "Photo " + idx;
	    s.events= "";
	    void(s.t());
	  });
	return false;
      });
    $('.gallery-nav #next a').click( function() {
	var next = $('ul#more-in-this-gallery-inner li.selected').next().find('a');
	next.trigger('click');
	//if (!next) { alert('no next!'); $(this).addClass('disabled'); } else { $(this).removeClass('disabled'); }
	return false;
      });
    $('.gallery-nav #previous a').click( function() {
	var prev = $('ul#more-in-this-gallery-inner li.selected').prev().find('a');
	prev.trigger('click');
	//if (!prev) { $(this).addClass('disabled'); } else { $(this).removeClass('disabled'); }
	return false;
      });
    /*
    $('#gallery-more').hover( function() {
	$(this).animate({ 'bottom': '+=120' }, 'slow');
      }, function() {
	$(this).animate({ 'bottom': '-=120' }, 'slow');
      });
    */
    $('ul#more-in-this-gallery-inner li a').click( function() {
	var a = $(this).attr('href');
        if ( $(this).parent().hasClass('selected') ) return false;
	var t = $(this).attr('alt');
	var c = $(this).attr('title');
	var img = '<img class="slide next" src="'+a+'" alt="'+t+'" />';
        $('.gallery-slide').append(img);
	$('.gallery-slide img.current').fadeOut('fast', function() { $(this).remove(); });
	$('.gallery-slide img.next').fadeIn('fast', function() { $(this).removeClass('next').addClass('current'); });
	$('h4.image-title').html(t);
	$('.image-caption').html(c);
	$('ul#more-in-this-gallery-inner li.selected').removeClass('selected');
	var i = $(this).parent().addClass('selected').attr('jcarouselindex');
	$('#photo-number .current').html(i);
        $(this).parent().parent().parent().parent().parent().parent().parent().trigger('slidechange', [ i ] );
	return false;
      });
});
