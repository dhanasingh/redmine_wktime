$(function(){
  getGeoLocation();
});

function getGeoLocation(){
  if(navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(success, error, {
      enableHighAccuracy: false, timeout: 10000, maximumAge: 15000
    });
  } else {
    error();
  }
}

function success(position) {
  myLongitude = position.coords.longitude;
  myLatitude = position.coords.latitude;
  if($('#mapContainer').length > 0){
    if(!show_on_map) showMap(myLongitude, myLatitude);
    $('#longitude').val(myLongitude);
    $('#latitude').val(myLatitude);
  }
}

function error(err) {
  if(err) console.log(err);
  if($('#mapContainer').length > 0 && typeof showMap === 'function'){
    showMap(0, 0);
  }
}
