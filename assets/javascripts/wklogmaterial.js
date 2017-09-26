 $(document).ready(function() {	
	hideLogDetails(null);
});
/*
function hideLogDetails()
{
	var logType = document.getElementById("log_type").value;
	if(logType == 'T')
	{
		document.getElementById('time_entry_hours').style.display = 'block';
		$('label[for="time_entry_hours"]').css('display', 'block');
		//$('label[for="time_entry_hours"]').html('Hours<span style="color:red;">*</span>');
		document.getElementById("materialtable").style.display = 'none';
		document.getElementById("expensetable").style.display = 'none';
	}
	else if(logType == 'E') {
		document.getElementById('time_entry_hours').style.display = 'none';
		$('label[for="time_entry_hours"]').css('display', 'none');
		//$('label[for="time_entry_hours"]').html('Amount<span style="color:red;">*</span>');
		document.getElementById("materialtable").style.display = 'none';
		document.getElementById("expensetable").style.display = 'block';
	}
	else 
	{
		document.getElementById('time_entry_hours').style.display = 'none';
		$('label[for="time_entry_hours"]').css('display', 'none');
		document.getElementById("expensetable").style.display = 'none';
		document.getElementById("materialtable").style.display = 'block';
		
	}
	
} */

function updateTotal(currId, nxtId, setId, currencyId)
{
	var currElement = document.getElementById(currId);
	var nxtElement = document.getElementById(nxtId);
	var totAmount = parseFloat(currElement.value) * parseFloat(nxtElement.value);
	document.getElementById(setId).innerHTML = document.getElementById(currencyId).innerHTML + totAmount.toFixed(2);
}