
var basicAction="";
var payrollId = 0;
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
				listBoxID = dlgname == 'Basic' ? "settings_wktime_payroll_basic" : (dlgname == 'Allownaces' ? 'settings_wktime_payroll_allowances' : 'settings_wktime_payroll_deduction')
				var listBox = document.getElementById(listBoxID);
				var name = document.getElementById("name");				
				var salary_type = document.getElementById("salary_type"); 
				var pay_period = document.getElementById("pay_period");
				var basic_field_factor = document.getElementById("basic_field_factor");
				if(dlgname != 'Basic')
				{
					frequency = document.getElementById("frequency");
					startdate = document.getElementById("start_date").value;				
					var dependent = document.getElementById("dep_value") ;
					var factor = document.getElementById("factor");
				}		
				
				if( !checkDuplicate(listBox,name.value) && name.value != "" && (startdate != ""  || dlgname == 'Basic') ){ 
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
						if(dlgname != 'Basic')
						{
							if (frequency.value != ""){
								desc = desc + "|"  + frequency.value;
								opttext = opttext + " : "  + frequency.options[frequency.selectedIndex].text + " : "  + startdate;
							}						
							desc = desc + "|"  + startdate;
							desc = desc + "|"  + dependent.value + "|"  + factor.value;
							opttext = opttext  +  (dependent.value != "" ? " : " + dependent.options[dependent.selectedIndex].text : " : " ) + " : " +  factor.value;
						}
						else{
							desc = desc + "|"  + salary_type.value;			
							if (salary_type.value != ""){
								opttext = opttext  + " : " + salary_type.options[salary_type.selectedIndex].text;
							}
							desc = desc + "|"  + basic_field_factor.value;			
								opttext = opttext  + " : " + basic_field_factor.value;
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
					if(checkDuplicate(listBox,name.value)){
						alertMsg += payroll_name + "\n";
					}	
					if(startdate == "" && frequency.value != "" )
					{
						alertMsg +=  "Please select the satrt date \n";
					}
					alert(alertMsg);
				}
				
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	
	
});

function payrollDialogAction(dlg, action)
{
	$( "#payroll-dlg" ).dialog({ title: dlg });
	basicAction = action;
	dlgname = dlg;
	listBoxID = dlgname == 'Basic' ? "settings_wktime_payroll_basic" : (dlgname == 'Allownaces' ? 'settings_wktime_payroll_allowances' : 'settings_wktime_payroll_deduction')
		var listbox = document.getElementById(listBoxID);
	if('Basic' == dlg)
	{
		document.getElementById("basic_salary_type").style.display = 'block';
		document.getElementById("basic_factor").style.display = 'block';
		document.getElementById("table_payroll_dependent").style.display = 'none';		
		document.getElementById("payroll_frequency").style.display = 'none';
		document.getElementById("payroll_start_date").style.display = 'none';
		if('Add' == action)
		{	
			$( "#payroll-dlg" ).dialog( "open" )	
		}		
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
		{
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			payrollId = listboxArr[0];
			document.getElementById("name").value = listboxArr[1];
			document.getElementById("salary_type").value = listboxArr[2];
			document.getElementById('basic_field_factor').value = listboxArr[3];
			$( "#payroll-dlg" ).dialog( "open" )			
		}
	    else if(listbox != null && listbox.options.length >0)
		{		
			alert(selectListAlertMsg);				
		}
					
	}
	else if(('Allownaces' == dlg) || ('Deduction' == dlg))
	{
		document.getElementById("basic_salary_type").style.display = 'none';
		document.getElementById("basic_factor").style.display = 'none';
		document.getElementById("table_payroll_dependent").style.display = 'block'; 
		document.getElementById("payroll_frequency").style.display = 'block';
		document.getElementById("payroll_start_date").style.display = 'block';
		if('Add' == action)
		{	
			$( "#payroll-dlg" ).dialog( "open" )	
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
		{		
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			payrollId = listboxArr[0];
			document.getElementById("name").value = listboxArr[1];
			document.getElementById("frequency").value = listboxArr[2];
			document.getElementById('start_date').value = listboxArr[3];
			document.getElementById("dep_value").value = listboxArr[4];
			document.getElementById('factor').value = listboxArr[5];
			$( "#payroll-dlg" ).dialog( "open" )
		}
		else if(listbox != null && listbox.options.length >0)
		{		
			alert(selectListAlertMsg);				
		}
	}		
}