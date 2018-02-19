$(document).ready(function() {
	var billingtype = document.getElementById('billing_type').value;
	var istax = document.getElementById('applytax').checked;
	showorHide(istax, 'applicable_taxes', null);
	showorHide((billingtype == 'FC' ? true : false), 'billingschdules', null);
	/** initially load the datepicker in milestone bill date textfield **/
	$('.date').each(function() {
        $(this).datepicker({ dateFormat: 'yy-mm-dd' });
	});
});

function showorHide(isshow, divId, divId1)
{
	if(isshow)
	{
		if(divId != null)
		{
			document.getElementById(divId).style.display = 'block'; 
		}
		if(divId1 != null)
		{
			document.getElementById(divId1).style.display = 'block';
		}
		 			
	}
	else {
		if(divId != null)
		{
			document.getElementById(divId).style.display = 'none'; 
		}
		if(divId1 != null)
		{
			document.getElementById(divId1).style.display = 'none';
		}
	}
}

