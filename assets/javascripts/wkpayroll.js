//jquery code for the payroll

function overrideSettings(chkboxelement){
	var chkboxid = chkboxelement.id;
	var isOverride = chkboxelement.checked;
	var id = chkboxid.replace("is_override", "");
	var dependentDD = document.getElementById('dependent_id'+id);
	var factorTxtBox = document.getElementById('factor'+id);
	dependentDD.disabled = !isOverride;
	factorTxtBox.disabled = !isOverride;
}

function payrollFormSubmission()
{ 
	var dateval = new Date(document.getElementById("to").value);
	dateval.setDate(dateval.getDate() + 1);
	var salaryDate = dateval.getFullYear() + '-' + (("0" + (dateval.getMonth() + 1)).slice(-2)) + '-' + (("0" + dateval.getDate()).slice(-2));
	const confirmationText = $('.label_confirmation_salary_text').data('confirmation');
	var isFormSubmission = confirm(`${confirmationText} ` + salaryDate);
	if (isFormSubmission == true) {
		document.getElementById("generate").value = true; 
		document.getElementById("query_form").submit();
	} 
}


$(function() {

    $( "#myDialog" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: false,		
		buttons: {
			"Ok": function() {
			var fromdate = document.getElementById("start_date").value;
			if(fromdate != "")
			{
				$.ajax({
				url: runperiodUrl,
				type: 'get',
				data: {fromdate:fromdate},
				success: function(data){ alert("sucessfully updated."); },   
				});
				$( this ).dialog( "close" );
			} else {
				const selectDateText = $('.label_select_date_text').data('select');
				alert(`${selectDateText}`);
			}
				
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});
	
});

function runperiodDatePicker()
{
	$( "#myDialog" ).dialog( "open" );
}