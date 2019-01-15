$(document).ready(function(){
	
	disableComponents(null);
});

function loadStatus(fldId)
{
	disableComponents(fldId);
}

function disableComponents(fldId)
{
	var loadActType = document.getElementById("load_act_type");
	var activityType = fldId == null ? loadActType.value : document.getElementById(fldId).value;
	var lblduration = document.getElementById("lblduration");
	var activityDuration = document.getElementById("activity_duration");
	var activity_duration_min = document.getElementById("activity_duration_min");
	var locationdd = document.getElementById("location");
	var lblLocation = document.getElementById("lblLocation");
	var lblEndDate = document.getElementById("lblEndDate");
	var activity_end_date = document.getElementById("enddatediv");
	var end_hour = document.getElementById("end_hour");
	var end_min = document.getElementById("end_min");
	var activity_direction = document.getElementById("activity_direction");
	var task_status = document.getElementById("task_status");
	var activity_status = document.getElementById("activity_status");
	if(activityType == 'M')
	{
		lblduration.style.display = 'block';
		activityDuration.style.display = 'block';
		activity_duration_min.style.display = 'block';
		lblLocation.style.display = 'block';
		locationdd.style.display = 'block';
		lblEndDate.style.display = 'block';
		activity_end_date.style.display = 'block';
		end_hour.style.display = 'block';
		end_min.style.display = 'block';
		activity_direction.style.display = 'none';
		task_status.style.display = 'none';
		activity_status.style.display = 'block';
		activity_status.style.cssFloat = "left";
	}
	if(activityType == 'C') {
		lblduration.style.display = 'block';
		activityDuration.style.display = 'block';
		activity_duration_min.style.display = 'block';
		lblLocation.style.display = 'none';
		locationdd.style.display = 'none';
		lblEndDate.style.display = 'none';
		activity_end_date.style.display = 'none';
		end_hour.style.display = 'none';
		end_min.style.display = 'none';
		activity_direction.style.display = 'block';
		task_status.style.display = 'none';
		activity_status.style.display = 'block';
		activity_status.style.cssFloat = "right";
	}
	if(activityType == 'T') {
		lblduration.style.display = 'none';
		activityDuration.style.display = 'none';
		activity_duration_min.style.display = 'none';
		lblLocation.style.display = 'none';
		locationdd.style.display = 'none';		
		lblEndDate.style.display = 'block';
		activity_end_date.style.display = 'block';
		end_hour.style.display = 'block';
		end_min.style.display = 'block';
		activity_direction.style.display = 'none';
		task_status.style.display = 'block';
		activity_status.style.display = 'none';
		
	}
}