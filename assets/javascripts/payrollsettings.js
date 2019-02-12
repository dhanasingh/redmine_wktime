
var basicAction="";
var payrollId = 0;
var editedname="";
$(document).ready(function(){
	var listBox = document.getElementById("settings_wktime_payroll_basic");
	if ($('#settings_wktime_payroll_basic').children().length != 0) {
		document.getElementById('basic_add').style.display = 'none';
	}
	document.getElementById('settings_payroll_deleted_ids').value = "";
	$( "#payroll-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: false,		
		buttons: {
			"Ok": function() {
				var opt,desc="",opttext="";
				var frequency = "";
				var startdate = "";
				listBoxID = dlgname == 'Calculated Fields' ? 'settings_wktime_payroll_calculated_fields' : (dlgname == 'Basic' ? "settings_wktime_payroll_basic" : (dlgname == 'Allowances' ? 'settings_wktime_payroll_allowances' : 'settings_wktime_payroll_deduction'))
				var listBox = document.getElementById(listBoxID);
				var name = document.getElementById("name");									
				var salary_type = document.getElementById("salary_type"); 
				var cftype = document.getElementById("calculated_fields_type"); 
				var pay_period = document.getElementById("pay_period");
				var basic_field_factor = document.getElementById("basic_field_factor");
				if(dlgname != 'Basic')
				{
					frequency = document.getElementById("frequency");
					startdate = document.getElementById("start_date").value;				
					var dependent = document.getElementById("dep_value") ;
					var factor = document.getElementById("factor");
				}
				var ledgerId = document.getElementById("payroll_db_ledger");
				if( !checkDuplicateComponent(listBox,name.value) && name.value != "" && (basic_field_factor.value != "" || dlgname != 'Basic' ) && ( (startdate != "" || (frequency.value == '' || frequency.value == 'm')  ) || dlgname == 'Basic') ){
					if('Add'== basicAction){
						opt = document.createElement("option");
						listBox.options.add(opt);
					}
					else if('Edit' == basicAction){ 						
						opt = listBox.options[listBox.selectedIndex];
					}
					if (name.value != ""){
						desc = ( (payrollId != 0 && basicAction == 'Edit') ?  payrollId + "|" : "|" )  + name.value
						opttext = name.value											
						if(dlgname != 'Basic' && dlgname != 'Calculated Fields')
						{
						//	if (frequency.value != ""){
							desc = desc + "|"  + frequency.value;
							opttext = opttext + " : "  + (frequency.value == '' ? '' : frequency.options[frequency.selectedIndex].text)  + " : "  + startdate;
						//	}						
							desc = desc + "|"  + startdate;
							desc = desc + "|"  + dependent.value + "|"  + (factor.value == '' ? 0 : factor.value) + "|"  + ledgerId.value ;
							opttext = opttext  +  (dependent.value != "" ? " : " + dependent.options[dependent.selectedIndex].text : " : " ) + " : " +  (factor.value == '' ? 0 : factor.value) + (ledgerId.value == '' ? '' : " : " + ledgerId.options[ledgerId.selectedIndex].text );
						}
						else if (dlgname != 'Calculated Fields'){
							desc = desc + "|"  + salary_type.value;			
							if (salary_type.value != ""){
								opttext = opttext  + " : " + salary_type.options[salary_type.selectedIndex].text;
							}
							desc = desc + "|"  + (basic_field_factor.value == null ? 0 : basic_field_factor.value) + "|"  + ledgerId.value;			
							opttext = opttext  + " : " + (basic_field_factor.value == null ? 0 : basic_field_factor.value) ;
							if (ledgerId.value != ""){
								opttext = opttext  + " : " + ledgerId.options[ledgerId.selectedIndex].text;
							}
						}
						else{
							desc = desc ;
							opttext = opttext ;
							desc = desc + "|"  + cftype.value;
							if (cftype.value != ""){
								opttext = opttext + " : " + cftype.options[cftype.selectedIndex].text;
							}
						}
					}
					opt.text =  opttext;
					opt.value = desc;						
					$( this ).dialog( "close" );	
				}
				else{
					var alertMsg = "";
					if(name.value == "")
					{
						alertMsg += payroll_name_errormsg + "\n";
					}
					if(checkDuplicateComponent(listBox, name.value)){
						alertMsg += payroll_name + "\n";
					}
					if( basic_field_factor.value == "" && dlgname == 'Basic')
					{
						alertMsg += payroll_factor_errormsg + "\n";
					}
					if(((frequency.value != "" && startdate == "") || (frequency.value != "m" && startdate == "")) && dlgname != 'Basic' && !checkDuplicateComponent(listBox,name.value) )
					{
						alertMsg +=  payroll_date_errormsg + "\n";
					}
					alert(alertMsg);
				}
				
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	
	
	$("form").submit(function() {
		
		var wktime_payroll_basic=document.getElementById("settings_wktime_payroll_basic");
		if(wktime_payroll_basic != null)
		{
			for(i = 0; i < wktime_payroll_basic.options.length; i++)
			{
				wktime_payroll_basic.options[i].selected = true;
			}
		}
		
		var payroll_allowances=document.getElementById("settings_wktime_payroll_allowances");
		if(payroll_allowances != null)
		{
			for(i = 0; i < payroll_allowances.options.length; i++)
			{
				payroll_allowances.options[i].selected = true;
			}						
		}
		
		var payroll_deduction=document.getElementById("settings_wktime_payroll_deduction");
		if(payroll_deduction != null)
		{ 
			for(i = 0; i < payroll_deduction.options.length; i++)
			{
				payroll_deduction.options[i].selected = true;
			}						
		}
		var payroll_calculated_fields=document.getElementById("settings_wktime_payroll_calculated_fields");
		if(payroll_calculated_fields != null)
		{ 
			for(i = 0; i < payroll_calculated_fields.options.length; i++)
			{
				payroll_calculated_fields.options[i].selected = true;
			}						
		}
	});
});

function payrollDialogAction(dlg, action)
{
	$( "#payroll-dlg" ).dialog({ title: (dlg == 'Basic' ? "Basic Pay" : dlg) });
	basicAction = action;
	dlgname = dlg;
	listBoxID = dlgname == 'Calculated Fields' ? 'settings_wktime_payroll_calculated_fields' : (dlgname == 'Basic' ? "settings_wktime_payroll_basic" : (dlgname == 'Allowances' ? 'settings_wktime_payroll_allowances' : 'settings_wktime_payroll_deduction'))
	var listbox = document.getElementById(listBoxID);
	if(dlg == 'Deduction')
	{
		document.getElementById("ledgersLabel").innerHTML = lblcreditLedger;
	}
	else{
		document.getElementById("ledgersLabel").innerHTML = lbldebitLedger;
	}
	if('Basic' == dlg)
	{
		document.getElementById("basic_salary_type").style.display = 'block';
		document.getElementById("basic_factor").style.display = 'block';
		document.getElementById("table_payroll_dependent").style.display = 'none';		
		document.getElementById("payroll_frequency").style.display = 'none';
		document.getElementById("payroll_start_date").style.display = 'none';
		$('#calculatedFieldsType').hide();
		$('#payrollDBLedger').show();
		if('Add' == action)
		{	
			editedname =  "" ;
			$( "#payroll-dlg" ).dialog( "open" )	
		}		
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
		{
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			payrollId = listboxArr[0];
			document.getElementById("name").value = listboxArr[1];
			editedname =  listboxArr[1] ;
			document.getElementById("salary_type").value = listboxArr[2];
			document.getElementById('basic_field_factor').value = listboxArr[3];
			document.getElementById('payroll_db_ledger').value = listboxArr[4];
			$( "#payroll-dlg" ).dialog( "open" )			
		}
	    else if(listbox != null && listbox.options.length >0)
		{		
			alert(selectListAlertMsg);				
		}
					
	}
	else if(('Allowances' == dlg) || ('Deduction' == dlg))
	{
		document.getElementById("basic_salary_type").style.display = 'none';
		document.getElementById("basic_factor").style.display = 'none';
		$('#calculatedFieldsType').hide();
		document.getElementById("table_payroll_dependent").style.display = 'block'; 
		document.getElementById("payroll_frequency").style.display = 'block';
		document.getElementById("payroll_start_date").style.display = 'block';
		document.getElementById("payrollDBLedger").style.display = 'block';
		var csName = document.getElementById("name");
		var csFrequency = document.getElementById("frequency");
		var csstart_date = document.getElementById('start_date');
		var csdep_value = document.getElementById("dep_value");
		var csfactor = document.getElementById('factor');
		var csledger = document.getElementById('payroll_db_ledger');
		if('Add' == action)
		{	
			csName.value = '';
			editedname =  "" ;
			csFrequency.value = '';
			csstart_date.value = '';
			csdep_value.value = '';
			csfactor.value = '';
			csledger.value = '';
			$( "#payroll-dlg" ).dialog( "open" )	
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
		{		
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			payrollId = listboxArr[0];
			csName.value = listboxArr[1];
			editedname =  listboxArr[1] ;
			csFrequency.value = listboxArr[2];
			csstart_date.value = listboxArr[3];
			csdep_value.value = listboxArr[4];
			csfactor.value = listboxArr[5];
			csledger.value = listboxArr[6];
			$( "#payroll-dlg" ).dialog( "open" )
		}
		else if(listbox != null && listbox.options.length >0)
		{		
			alert(selectListAlertMsg);				
		}
	}
	else if('Calculated Fields' == dlg)
	{
		$("#basic_salary_type").hide();
		$("#table_payroll_dependent").hide();
		$("#payrollDBLedger").hide();
		$("#payroll_frequency").hide();
		$("#payroll_start_date").hide();
		$('#basic_factor').hide();
		$('#calculatedFieldsType').show();
		var csName = document.getElementById("name");
		var cftype = document.getElementById('calculated_fields_type');
		
		if('Add' == action)
		{	
			csName.value = '';
			editedname =  '';
			cftype.value = 'BAT';
			$( "#payroll-dlg" ).dialog( "open" )	
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
		{		
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			payrollId = listboxArr[0];
			csName.value = listboxArr[1];
			editedname =  listboxArr[1] ;
			cftype.value = listboxArr[2];
			$( "#payroll-dlg" ).dialog( "open" )
		}
		else if(listbox != null && listbox.options.length >0)
		{		
			alert(selectListAlertMsg);				
		}
	}
}

function checkDuplicateComponent(listbox, newValue)
{
	isDuplicate = false;
	var listboxArr;	
	for(i=0; i< listbox.options.length; i++)
	 {
		listboxArr=listbox.options[i].value.split('|');	
		if(newValue == listboxArr[1] && (editedname != newValue ) )
		{
			isDuplicate=true;
		}
	 }		 
	 return isDuplicate;
}

function removeSelectedValue(elementId)
{
	var listbox=document.getElementById(elementId);
	if(listbox != null && listbox.options.selectedIndex >= 0)
	 { 				
		if (confirm(attendanceAlertMsg))
		{
			//removes options from listbox			
			//listbox.remove(listbox.options.selectedIndex);
			
			var i;
			for(i=listbox.options.length-1;i>=0;i--)
			{					
				if(listbox.options[i].selected)	
				{
					if(elementId == 'settings_wktime_payroll_allowances' || elementId == 'settings_wktime_payroll_deduction' || elementId == 'settings_wktime_payroll_calculated_fields')
					{
						var listboxArr = listbox.options[i].value.split('|');
						var payroll_ids = document.getElementById('settings_payroll_deleted_ids').value;
						ids = payroll_ids == "" ? listboxArr[0] : (payroll_ids + "|" + listboxArr[0]);
						document.getElementById('settings_payroll_deleted_ids').value = ids;
					}
					listbox.remove(i);
				}
			}
		}			
	}
	else if(listbox != null && listbox.options.length >0)
	{
		alert(selectListAlertMsg);
	}
}
