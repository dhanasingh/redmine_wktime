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
	var isFormSubmission = confirm("Are you sure want to generate salary on " + salaryDate);
	if (isFormSubmission == true) {
		document.getElementById("generate").value = true; 
		document.getElementById("query_form").submit();
	} 
}