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
	$('.start_on').change(function() {
		console.log("---start_time in-----")
		if(hasAllValues()){
			setEndTime();
		}
	});

	$('.end_on').change(function() {
		console.log("---end_on in-----")
		if(hasAllValues()) calculateHours();
	});

	$("#time_entry_hours").change(function() {
		setEndTime();
	});

	if(	$("#time_entry_hours").val() != '' && hasAllValues('start_on') ) {
		setEndTime();
	}
});

function hasAllValues(singleEle){
	var hasAllVal = true;
	var selector = singleEle ? singleEle : 'start_on, .end_on';
	$('.'+selector).each(function(){
		if(!$(this).val()) hasAllVal = false;
	});
	return hasAllVal && $("#time_entry_hours").is(":visible");
}

function updateTotal(currId, nxtId, setId, currencyId)
{
	var currElement = document.getElementById(currId);
	var nxtElement = document.getElementById(nxtId);
	var totAmount = parseFloat(currElement.value) * parseFloat(nxtElement.value);
	document.getElementById(setId).innerHTML = document.getElementById(currencyId).innerHTML + totAmount.toFixed(2);
}

function setEndTime(){
	var te_hours = $('#time_entry_hours').val();
	start_time = new Date($('#start_time_1i').val(), $('#start_time_2i').val(), $('#start_time_3i').val(), $('#start_time_4i').val(), $('#start_time_5i').val())
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
	$("#end__on_time_1i").val(start_time.getFullYear());
	$("#end__on_time_2i").val(start_time.getMonth());
	$("#end__on_time_3i").val(start_time.getDate());
	$("#end__on_time_4i").val(hours);
	$("#end__on_time_5i").val(minutes);
}

function calculateHours(){
	let start_time = formDateTime('start_on');
	let end_time = formDateTime('end_on');
	console.log(end_time);
	console.log(start_time);
	if(end_time < start_time){
		end_time.setDate(start_time.getDate() + 1)
	}
	let hours = (end_time.getTime() - start_time.getTime()) / 1000/3600;
	hours = hours.toFixed(2);
	$("#end__on_time_1i").val(end_time.getFullYear());
	$("#end__on_time_2i").val(end_time.getMonth());
	$("#end__on_time_3i").val(end_time.getDate());
	$('#time_entry_hours').val(hours);
}

function formDateTime(selector){
	let values = [];
	$('[name^="'+selector+'"]').each(function(){ values.push($(this).val()); });
	console.log(values);
	return (new Date(values[0], values[1], values[2], values[3], values[4]));
}