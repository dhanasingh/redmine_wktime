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

function payrollFormSubmission(isGenerate)
{ 
	var dateval = new Date(document.getElementById("to").value);
	var fromdateval = new Date(document.getElementById("from").value);
	dateval.setDate(dateval.getDate() + 1);
	var salaryDate = dateval.getFullYear() + '-' + (("0" + (dateval.getMonth() + 1)).slice(-2)) + '-' + (("0" + dateval.getDate()).slice(-2));
	const confirmationText = $('.label_confirmation_salary_text').data('confirmation');

	if(!isNaN(dateval.getFullYear()) || !isNaN(fromdateval.getFullYear()))
	{
		var isFormSubmission = isGenerate ? confirm(`${confirmationText} ` + salaryDate) : true;
		document.getElementById("generate").value = isGenerate;
		if(isFormSubmission)
			document.getElementById("query_form").submit();
	}
	else
	{
		alert("Please select valid date range");
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

	$("[id^='rowheader_'").each(function(){
		var id = this.id.split("_")[1];
		var height = $(this).height();
		$(".rowcontent_"+id).height(height);
	});

});

function runperiodDatePicker()
{
	$( "#myDialog" ).dialog( "open" );
}

function bulk_edit(colID){
	var button = $('#'+colID).prop('title');
	if(button == 'Edit'){
		$('#'+colID).prop('title', 'Update');
		$('#'+colID).removeClass();
		$('#'+colID).addClass("icon icon-save");
		$('[id^="td_'+colID+'_"]').each(function(){
			var text = $(this).text();
			var name = (this.id).substr(3)
			var input = '<input id="'+ name +'" name="'+ name +'" type="text" value="' + text + '" maxlength="7" size="10" />';
			input += '<input name="h_'+ name +'" id="h_'+ name +'" type="hidden" value="' + text + '">';
			$(this).html(input);
		});
	}
	else if(button == 'Update'){
		var form_data = {}
		var isInvalid = false;
		$('[id^="'+colID+'_"]').each(function(){
			var val = this.value;
			var old_val = $('#h_'+this.id).val();
			if( isNaN(val)){
				isInvalid = true;
			}else if(val != old_val){
				form_data[this.name] = val;
			}
		});
		
		if(!isInvalid && Object.keys(form_data).length > 0){
			var url = '/wkpayroll/save_bulk_edit';
			$.ajax({
				url: url,
				type: 'post',
				data: form_data,
		        cache: false,
				success: function(data){
					if(data != "ok") {
						alert(data);
					}else{
						setUserPayrollValues(colID, true);
					}
				},
				beforeSend: function(){
					$(this).parent().addClass('ajax-loading');
				},
				complete: function(){
					$(this).parent().removeClass('ajax-loading');
				}
			});
		}
		else if(Object.keys(form_data).length == 0 && !isInvalid){
			setUserPayrollValues(colID, true);
		}
		else{
			setUserPayrollValues(colID, false);
		}
	}

}

function setUserPayrollValues(colID, isValid){
	$('[id^="'+colID+'_"]').each(function(){
		if(!isValid){
			this.value = $('#h_'+this.id).val();
		}
		else{
			$('#'+colID).prop('title', 'Edit');
			$('#'+colID).removeClass();
			$('#'+colID).addClass("icon icon-edit");
			$('#td_'+this.id).html(this.value);
		}
	});
}
