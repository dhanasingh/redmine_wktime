$(function(){
  getGeoLocation();
});

function getGeoLocation(){
  if(!navigator.geolocation) {
    alert('Geolocation is not supported by your browser');
  } else {
    navigator.geolocation.getCurrentPosition(success, error, { enableHighAccuracy: true });
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

function error(error) {
  console.log(error)
}