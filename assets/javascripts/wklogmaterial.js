 $(document).ready(function() {	
	hideLogDetails(null);
	if(document.getElementById("time_entry_project_id") != null)
	{
		$('#time_entry_project_id').change(function(){
			var project=$(this);			
			uid = document.getElementById('userId').value;
		    loadSpentFors(project.val(), 'spent_for', false, uid)
		});
	}
	
	//Time Tracking
	$('.start_time').change(function() {
		if($('#time_entry_hours').val() != ''){
			setEndTime();
		}
	});
	$("#time_entry_hours").change(function() {
		if($('#start_time__4i').val() != ''){
			setEndTime();
		}
	});

	if(	$("#time_entry_hours").val() != '' && $('.start_time') != '' ) {
		setEndTime();
	}
	  
});

function updateTotal(currId, nxtId, setId, currencyId)
{
	var currElement = document.getElementById(currId);
	var nxtElement = document.getElementById(nxtId);
	var totAmount = parseFloat(currElement.value) * parseFloat(nxtElement.value);
	document.getElementById(setId).innerHTML = document.getElementById(currencyId).innerHTML + totAmount.toFixed(2);
}

function setEndTime(){
	var te_hours = $('#time_entry_hours').val();
	start_time = new Date($('#start_time__1i').val(), $('#start_time__2i').val(), $('#start_time__3i').val(), $('#start_time__4i').val(), $('#start_time__5i').val())
	if(te_hours.includes(':')){
		te_hours = te_hours.split(':')
		totalMin = parseInt(te_hours[0] * 60) + parseInt(te_hours[1]);
	}
	else{
		var hours = Math.floor(te_hours);
		var minutes = Math.round((te_hours - hours) * 60);
		totalMin = parseInt(hours * 60) + parseInt(minutes);
	}	
	start_time.setMinutes( start_time.getMinutes() + totalMin );
	hours = start_time.getHours() < 10 ? "0" + start_time.getHours() : start_time.getHours();
	minutes = start_time.getMinutes() < 10 ? "0" + start_time.getMinutes() : start_time.getMinutes();
	$("#end_time__1i").val(start_time.getFullYear());
	$("#end_time__2i").val(start_time.getMonth());
	$("#end_time__3i").val(start_time.getDate());
	$("#end_time__4i").val(hours);
	$("#end_time__5i").val(minutes);
}

function calculateHours(){
	let start_time = new Date($('#start_time__1i').val(), $('#start_time__2i').val(), $('#start_time__3i').val(),
			$('#start_time__4i').val(), $('#start_time__5i').val());
	let end_time = new Date($('#start_time__1i').val(), $('#start_time__2i').val(), $('#start_time__3i').val(),
			$('#end_time__4i').val(), $('#end_time__5i').val());
	if(end_time < start_time){
		end_time.setDate(start_time.getDate() + 1)
	}
	let hours = (end_time.getTime() - start_time.getTime()) / 1000/3600;
	hours = hours.toFixed(2);
	$("#end_time__1i").val(end_time.getFullYear());
	$("#end_time__2i").val(end_time.getMonth());
	$("#end_time__3i").val(end_time.getDate());
	$('#time_entry_hours').val(hours);
}