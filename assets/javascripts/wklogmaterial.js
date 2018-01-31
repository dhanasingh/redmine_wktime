 $(document).ready(function() {	
	hideLogDetails(null);
});

function updateTotal(currId, nxtId, setId, currencyId)
{
	var currElement = document.getElementById(currId);
	var nxtElement = document.getElementById(nxtId);
	var totAmount = parseFloat(currElement.value) * parseFloat(nxtElement.value);
	document.getElementById(setId).innerHTML = document.getElementById(currencyId).innerHTML + totAmount.toFixed(2);
}