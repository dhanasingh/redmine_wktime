$(document).ready(function() {
	if(document.getElementById('billing_type') != null)
	{
		var billingtype = document.getElementById('billing_type').value;		
		showorHide((billingtype == 'FC' ? true : false), 'billingschdules', null);
	}
	if(document.getElementById('applytax') != null)
	{
		var istax = document.getElementById('applytax').checked;
		showorHide(istax, 'applicable_taxes', null);
	}
	
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

