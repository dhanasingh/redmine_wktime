$(document).ready(function() {
	var billingtype = document.getElementById('billing_type').value;
	var istax = document.getElementById('applytax').checked;
	showorHide(istax, 'applicable_taxes');
	showorHide((billingtype == 'FC' ? true : false), 'billingschdules');
	/** initially load the datepicker in milestone bill date textfield **/
	$('.date').each(function() {
        $(this).datepicker({ dateFormat: 'yy-mm-dd' });
	});
});

function showorHide(isshow, divId)
{
	if(isshow)
	{
		document.getElementById(divId).style.display = 'block';		
	}
	else {
		document.getElementById(divId).style.display = 'none';
	}
}

