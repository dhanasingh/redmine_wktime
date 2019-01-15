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
	  
});

function updateTotal(currId, nxtId, setId, currencyId)
{
	var currElement = document.getElementById(currId);
	var nxtElement = document.getElementById(nxtId);
	var totAmount = parseFloat(currElement.value) * parseFloat(nxtElement.value);
	document.getElementById(setId).innerHTML = document.getElementById(currencyId).innerHTML + totAmount.toFixed(2);
}