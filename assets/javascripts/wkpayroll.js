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

function bulk_edit(ele){
	var button = $('#'+ele).prop('title');
	if(button == 'Edit'){
		$('#'+ele).prop('title', 'Update');
		$('#'+ele).removeClass();
		$('#'+ele).addClass("icon icon-save");
		$('[id^="td_'+ele+'"]').each(function(){
			if((this.id).split("_").length > 2){
				var text = $(this).text();
				var name = (this.id).substr(3)
				var input = '<input id="'+ name +'" name="'+ name +'" type="text" value="' + text + '" maxlength="7" size="10" />';
				input += '<input name="h_'+ name +'" id="h_'+ name +'" type="hidden" value="' + text + '">';
	 			$(this).html(input);
 			}
		});
	}
	else if(button == 'Update'){
		var form_data = {}
		var isInvalid = false;
		$('[id^="'+ele+'"]').each(function(){
			var ele_id = (this.id).split("_");
			if(ele_id[ele_id.length-1] > 0){
				var val = parseFloat(this.value);
				var old_val = parseFloat($('#h_'+this.id).val());
				if( isNaN(val)){
					isInvalid = true;
				}else if(val != old_val){
					form_data[this.name] = val;
 				}
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
						$('#'+ele).prop('title', 'Edit');
						$('#'+ele).removeClass();
						$('#'+ele).addClass("icon icon-edit");
						$('[id^="'+ele+'"]').each(function(){
							if((this.id).split("_").length > 2)
	 							$('#td_'+this.id).html(this.value);
	 					});
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
	}

}