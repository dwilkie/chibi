$(document).ready(function(){


  $(".highlight_number").click( function(){
    $(".number").effect("highlight", {}, 5000);
  } );

  //---------------------------
  // Content Slider
  //---------------------------
  if( $(".slider").length ){

    // Init the slider
    var slider = $(".slider"),
      slideWidth = slider.find("li").eq(0).width(),
      num = slider.find("li").length,
      sliderController = $(".sliderController");

    slider.width( num * slideWidth );

    // center the arrows and add click event
    $(".arrow").height(
      slider.height()
    ).click( function(){
      slideTo( $(this).attr("rel") );
      return false;
    } );

    // build the controller
    for( i=0; i<num; i++ ){
      var li = $('<li><a href="#"></a></li>');
      li.click(function(){
        slideTo( $(this).index() );
        return false;
      }).appendTo(sliderController);
    }

    // Set width to the controller to center it
    sliderController.width(
      num * 25
    ).find("li").eq(0).addClass("current");

    // Do slide
    function slideTo( next ){
      var current = sliderController.find(".current"),
        currentIndex = current.index();

      if( next == "next" ) {
        next = currentIndex + 1;
        if( next == num ) { next = 0; }
      }
      if( next == "prev" ) {
        next = currentIndex - 1;
        if( next < 0 ) { next = num-1; }
      }

      if( (next < num) && !(next < 0) ) {

        slider.animate({
          left: - ( next * slideWidth )
        });

        current.removeClass("current");
        sliderController.find("li").eq(next).addClass("current");

      }
    }
  }
});
