/*

File: superphy_slideshow.js
Desc: Creates slideshows on homepage and adds labels
Author: Jason Masih jason.masih@phac-aspc.gc.ca
Date: January 28, 2015

*/

/* Switches images in first slideshow */
function slideShow1() {
	var $active, $next;
	$active = $('#slideshow-img1 IMG.active');
	if ($active.length === 0) $active = $('#slideshow-img1 IMG:last');
	$next = $active.next().length ? $active.next()
		: $('#slideshow-img1 IMG:first');
	$active.addClass('last-active');
	$next.css({opacity: 0.0})
		.addClass('active')
		.animate({opacity: 1.0}, 1000, function() {
			$active.removeClass('active last-active');
	});
}

/* Switches images in second slideshow */
function slideShow2() {
	var $active, $next;
	$active = $('#slideshow-img2 IMG.active');
	if ($active.length === 0) $active = $('#slideshow-img2 IMG:last');
	$next = $active.next().length ? $active.next()
		: $('#slideshow-img2 IMG:first');
	$active.addClass('last-active');
	$next.css({opacity: 0.0})
		.addClass('active')
		.animate({opacity: 1.0}, 1000, function() {
			$active.removeClass('active last-active');
	});
}

/* Switches images in third slideshow */
function slideShow3() {
	var $active, $next;
	$active = $('#slideshow-img3 IMG.active');
	if ($active.length === 0) $active = $('#slideshow-img3 IMG:last');
	$next = $active.next().length ? $active.next()
		: $('#slideshow-img3 IMG:first');
	$active.addClass('last-active');
	$next.css({opacity: 0.0})
		.addClass('active')
		.animate({opacity: 1.0}, 1000, function() {
			$active.removeClass('active last-active');
	});
}

/* Adds label to each slideshow on hover */
function slideShowLabel1() {
    var original = $('.slideshow-label').css('opacity');
    $('#slideshow1').hover(function (e) {
        $('#slideshow-label1').stop().animate(
            {"opacity" : "0.8"}, 250);
    }, function (e){
        $('#slideshow-label1').stop().animate(
            {"opacity": original}, 250);
    });
}

/* Adds label to each slideshow on hover */
function slideShowLabel2() {
    var original = $('.slideshow-label').css('opacity');
    $('#slideshow2').hover(function (e) {
        $('#slideshow-label2').stop().animate(
            {"opacity" : "0.8"}, 250);
    }, function (e){
        $('#slideshow-label2').stop().animate(
            {"opacity": original}, 250);
    });
}

/* Adds label to each slideshow on hover */
function slideShowLabel3() {
    var original = $('.slideshow-label').css('opacity');
    $('#slideshow3').hover(function (e) {
        $('#slideshow-label3').stop().animate(
            {"opacity" : "0.8"}, 250);
    }, function (e){
        $('#slideshow-label3').stop().animate(
            {"opacity": original}, 250);
    });
}

$(function() {
	setTimeout(function() {setInterval("slideShow1()", 5000);}, 0);
	setTimeout(function() {setInterval("slideShow2()", 7000);}, 3000);
	setTimeout(function() {setInterval("slideShow3()", 6000);}, 0);
	slideShowLabel1();
	slideShowLabel2();
	slideShowLabel3();
});