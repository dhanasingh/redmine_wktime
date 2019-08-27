var holiDayAction="";
var breakTimeAction="";
var leaveAction="";
var invalidDate="";
var selectedDate="";
var selectedIssue="";
$(document).ready(function(){
	updateCustFldDD(document.getElementById('settings_wktime_enter_cf_in_row1'),'settings_wktime_enter_cf_in_row2');
	updateCustFldDD(document.getElementById('settings_wktime_enter_cf_in_row2'),'settings_wktime_enter_cf_in_row1');	
	dialogAction();

	//check all for module
	checked_modules();
	$(".modules").click(function () {
		checked_modules();
	});

	$(".checkall").click(function () {
		if ($(this).is(":checked")){
			$(".modules").prop("checked", true);
		}else {
			$(".modules").prop("checked", false);
		}
		checked_modules();
	});
});

function dialogAction()
{
	$( "#holiday-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: false,		
		buttons: {
			"Ok": function() {
				var opt,desc="";
				var holidayDate = document.getElementById("holiday_date").value;				
				if(holidayDate != "" && validateDate(holidayDate))
				{
					var listBox = document.getElementById("settings_wktime_public_holiday");
					if(!checkDuplicate(listBox,holidayDate)){

						if('Add'== holiDayAction){	
							opt = document.createElement("option");
							listBox.options.add(opt);
						}
						else if('Edit' == holiDayAction){
							opt = listBox.options[listBox.selectedIndex];
						}					
						if (document.getElementById("holiday_desc").value != ""){
							desc = " | " + document.getElementById("holiday_desc").value;
						}
						opt.text = holidayDate + desc;
						opt.value = holidayDate +  desc;	
						Sort('settings_wktime_public_holiday');
						$( this ).dialog( "close" );
					}
					else{
						alert(dateExistsAlertMsg);
					}
				}
				else{
					alert(invalidDate);
				}
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	
	
	$( "#breaktime-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: false,		
		buttons: {
			"Ok": function() {
				var opt,desc="",opttext="";
				var listBox = document.getElementById("settings_wktime_break_time");
				var fromHrEl = document.getElementById("break_from_hr");
				var fromMinEl = document.getElementById("break_from_min");
				var toHrEl = document.getElementById("break_to_hr");
				var toMinEl = document.getElementById("break_to_min");
				if('Add'== breakTimeAction){	
					opt = document.createElement("option");
					listBox.options.add(opt);
				}
				else if('Edit' == breakTimeAction){
					opt = listBox.options[listBox.selectedIndex];
				}			
				if (fromHrEl.value != ""){
					desc = fromHrEl.value;
					opttext = fromHrEl.options[fromHrEl.selectedIndex].text;
				}					
				if (fromMinEl.value != ""){
					desc = desc + "|"  + fromMinEl.value;
					opttext = opttext + ":"  + fromMinEl.options[fromMinEl.selectedIndex].text;
				}					
				if (toHrEl.value != ""){
					desc = desc + "|"  + toHrEl.value;
					opttext = opttext + " - "  + toHrEl.options[toHrEl.selectedIndex].text;
				}					
				if (toMinEl.value != ""){
					desc = desc + "|"  + toMinEl.value;
					opttext = opttext + ":"  + toMinEl.options[toMinEl.selectedIndex].text;
				}
				opt.text =  opttext;
				opt.value = desc;
				Sort('settings_wktime_break_time');
				$( this ).dialog( "close" );
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	
	
	$( "#leave-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: false,		
		buttons: {
			"Ok": function() {
				var opt,desc="",opttext="";
				var listBox = document.getElementById("settings_wktime_leave");
				var leaveIssue = document.getElementById("leave_issue");
				var leaveAccrual = document.getElementById("leave_accrual");
				var accrualAfter = document.getElementById("leave_accrual_after");
				var accrualMultiplier = document.getElementById("leave_accrual_multiplier");
				var resetMonth = document.getElementById("wk_attn_leave_reset_month");
				var shortName = document.getElementById("wk_leave_short_name");
				if(!checkDuplicate(listBox,leaveIssue.value) && !isNaN(leaveAccrual.value) && !isNaN(accrualAfter.value) && leaveIssue.value != "" && !isNaN(accrualMultiplier.value)){
					if('Add'== leaveAction){	
						opt = document.createElement("option");
						listBox.options.add(opt);
					}
					else if('Edit' == leaveAction){
						opt = listBox.options[listBox.selectedIndex];
					}			
					if (leaveIssue.value != ""){
						desc = leaveIssue.value
						opttext = leaveIssue.options[leaveIssue.selectedIndex].text;
						desc = desc + "|"  + leaveAccrual.value;				
						if (leaveAccrual.value != ""){
							opttext = opttext + " : "  + leaveAccrual.value + " " + lblDaysPerMonth;
						}
						desc = desc + "|"  + accrualAfter.value;			
						if (accrualAfter.value != ""){
							opttext = opttext + " " + lblAccrualAfter + " " + accrualAfter.value + " " + lblYear;
						}
						desc = desc + "|"  + resetMonth.value;	
						desc = desc + "|"  + shortName.value;
						desc = desc + "|"  + accrualMultiplier.value;
					}	
					opt.text =  opttext;
					opt.value = desc;
					$( this ).dialog( "close" );
				}
				else{
					var alertMsg = "";
					if(leaveIssue.value == ""){
						alertMsg = lblLeaveIssue + " "+ lblInvalid + "\n";
					}
					if(checkDuplicate(listBox,leaveIssue.value)){
						alertMsg = issueExistsAlertMsg + "\n";
					}
					if(isNaN(leaveAccrual.value)){
						alertMsg = alertMsg + lblAccrual + " "+ lblInvalid + "\n";
					}
					if(isNaN(accrualAfter.value)){
						alertMsg = alertMsg + lblAccrualAfter + " " + lblInvalid;
					}
					if(isNaN(accrualMultiplier.value)){
						alertMsg = alertMsg + lblAccrualMultiplier + " " + lblInvalid;
					}
					alert(alertMsg);
				}
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	
	
	$( "#invcomp-dlg" ).dialog({
		autoOpen: false,
		resizable: true,
		width: 380,
		modal: false,		
		buttons: {
			"Ok": function() {
				var opt,desc="",opttext="";
				var listBox = document.getElementById(listboxId);
				var invCompName = document.getElementById("inv_copm_name");
				var invCompVal = document.getElementById("inv_copm_value");
				if(invCompName.value != ""){  
					if('Add'== leaveAction){	
						opt = document.createElement("option");
						listBox.options.add(opt);
					}
					else if('Edit' == leaveAction){
						opt = listBox.options[listBox.selectedIndex];
					}			
					if (invCompName.value != ""){
						desc = invCompName.value
						opttext = desc + ":"  + invCompVal.value;
						desc = desc + "|"  + invCompVal.value;
					}	
					opt.text =  opttext;
					opt.value = desc;
					$( this ).dialog( "close" );
				}
				else{
					var alertMsg = "";					
					if(invCompName.value == ""){
						alertMsg = lblInvCompName + " "+ lblInvalid + "\n";
					}
					alert(alertMsg);
				}
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	
	
	
}

function updateCustFldDD(currCFDD,anotherCFDD)
{
	if(document.getElementById(anotherCFDD)!=null)
	{
		var anotherCFDD_Value = document.getElementById(anotherCFDD).value;
		document.getElementById(anotherCFDD).length = 0; //clear the existing values	
		var templateDD = document.getElementById('template_custFldDD');
		var ddlength = templateDD.options.length;
		var j = 0;
		//Refill the dropdown
		for(i=0; i < ddlength; i++)
		{
			if(currCFDD.value != templateDD.options[i].value || currCFDD.value == 0)
			{
				document.getElementById(anotherCFDD).options[j] = new Option(templateDD.options[i].text,templateDD.options[i].value,false,templateDD.options[i].value == anotherCFDD_Value);
				j++;
			}
		}
	}

}

	function getCurrentDate()
	{
		var today = new Date();
		today = today.getFullYear() + '-' + (("0" + (today.getMonth() + 1)).slice(-2)) + '-' + (("0" + today.getDate()).slice(-2));
		return today;
	}
	
	function showDialog(action)
	{
		var listbox = document.getElementById("settings_wktime_public_holiday");
		var holiDayDesc = document.getElementById("holiday_desc");
		var holidayDate = document.getElementById("holiday_date");
		holiDayDesc.value = "";
		if('Add' == action)
		{	
			holidayDate.value = getCurrentDate();
			holiDayAction = action;
			selectedDate="";
			$( "#holiday-dlg" ).dialog( "open" )	
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
		{				
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			holidayDate.value = listboxArr[0].trim();
			selectedDate=listboxArr[0].trim();
			if(listboxArr[1] != null)
				holiDayDesc.value = listboxArr[1].trim();
				holiDayAction = action;
			$( "#holiday-dlg" ).dialog( "open" )	
		}
		else if(listbox != null && listbox.options.length >0)
		{		
			alert(selectListAlertMsg);				
		}
	}

	function showBreakTimeDialog(action)
	{
		var listbox = document.getElementById("settings_wktime_break_time");
		var breakFromHr = document.getElementById("break_from_hr");
		var breakToHr = document.getElementById("break_to_hr");
		var breakFromMin = document.getElementById("break_from_min");
		var breakToMin = document.getElementById("break_to_min");
		if('Add' == action)
		{	
			breakTimeAction = action;
			$( "#breaktime-dlg" ).dialog( "open" )	
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
		{				
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			breakFromHr.value = listboxArr[0];
			breakFromMin.value = listboxArr[1];
			breakToHr.value = listboxArr[2];
			breakToMin.value = listboxArr[3];
			breakTimeAction = action;
			$( "#breaktime-dlg" ).dialog( "open" )	
		}
		else if(listbox != null && listbox.options.length >0)
		{		
			alert(selectListAlertMsg);				
		}
	}	

	function showLeaveDialog(action)
	{
		var listbox = document.getElementById("settings_wktime_leave");
		var leaveIssue = document.getElementById("leave_issue");
		var leaveProject = document.getElementById("leave_project");
		var leaveAccrual = document.getElementById("leave_accrual");
		var accrualMultiplier = document.getElementById("leave_accrual_multiplier");
		var accrualAfter = document.getElementById("leave_accrual_after");
		var resetMonth = document.getElementById("wk_attn_leave_reset_month");
		var shortName = document.getElementById("wk_leave_short_name");
		if('Add' == action)
		{	
			leaveAction = action;				
			var templateDD = document.getElementById('template_projDD');
			if(templateDD) {
				leaveProject.options.length = 0; //clear the existing values
				var ddlength = templateDD.options.length;			
				//Refill the dropdown
				for(i=0; i < ddlength; i++)
				{
					leaveProject.options[i] = new Option(templateDD.options[i].text,templateDD.options[i].value);
				}
			}
			leaveProject.selectedIndex = 0;
			projectChanged(leaveProject,-1);
			leaveAccrual.value = "";
			accrualAfter.value = "";
			accrualMultiplier.value = "1"
			selectedIssue="";
			resetMonth.value = 0
			shortName.value = "";
			$( "#leave-dlg" ).dialog( "open" )	
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
		{				
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			issueChanged(listboxArr[0]);
			selectedIssue=listboxArr[0];
			leaveAccrual.value = !listboxArr[1] ? "" : listboxArr[1];
			accrualAfter.value = !listboxArr[2] ? "" : listboxArr[2];
			resetMonth.value = listboxArr[3];
			shortName.value = !listboxArr[4] ? "" : listboxArr[4];
			accrualMultiplier.value = !listboxArr[5] ? "1" : listboxArr[5];
			leaveAction = action;
			$( "#leave-dlg" ).dialog( "open" )	
		}
		else if(listbox != null && listbox.options.length >0)
		{		
			alert(selectListAlertMsg);				
		}
	}		

	function showInvCompDialog(action, listId)
	{
		
		listboxId = listId;
		var listbox = document.getElementById(listboxId);
		var invCompName = document.getElementById("inv_copm_name");
		var invCompVal = document.getElementById("inv_copm_value");
		if('Add' == action)
		{	
			leaveAction = action;
			invCompName.value = "";
			invCompVal.value = "";
			$( "#invcomp-dlg" ).dialog( "open" )	
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
		{				
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			invCompName.value = !listboxArr[0] ? "" : listboxArr[0];
			invCompVal.value = !listboxArr[1] ? "" : listboxArr[1];
			leaveAction = action;
			$( "#invcomp-dlg" ).dialog( "open" )	
		}
		else if(listbox != null && listbox.options.length >0)
		{		
			alert(selectListAlertMsg);				
		}
	}		
	
	$("form").submit(function() {
		var listbox=document.getElementById("settings_wktime_public_holiday");
		if(listbox != null)
         { 
			for(i = 0; i < listbox.options.length; i++)
			{
				listbox.options[i].selected = true;
			}						
		}
		var btlistbox=document.getElementById("settings_wktime_break_time");
		if(btlistbox != null)
         { 
			for(i = 0; i < btlistbox.options.length; i++)
			{
				btlistbox.options[i].selected = true;
			}						
		}
		var lvlistbox=document.getElementById("settings_wktime_leave");
		if(lvlistbox != null)
         { 
			for(i = 0; i < lvlistbox.options.length; i++)
			{
				lvlistbox.options[i].selected = true;
			}						
		}
		var invlistbox=document.getElementById("settings_wktime_invoice_components");
		if(invlistbox != null)
         { 
			for(i = 0; i < invlistbox.options.length; i++)
			{
				invlistbox.options[i].selected = true;
			}						
		}
		var fldInFiles=document.getElementById("settings_wktime_fields_in_file");
		if(fldInFiles != null)
         { 
			for(i = 0; i < fldInFiles.options.length; i++)
			{
				fldInFiles.options[i].selected = true;
			}						
		}
		var quotelistbox=document.getElementById("settings_wktime_quote_components");
		if(quotelistbox != null)
         { 
			for(i = 0; i < quotelistbox.options.length; i++)
			{
				quotelistbox.options[i].selected = true;
			}						
		}
		var polistbox=document.getElementById("settings_wktime_po_components");
		if(polistbox != null)
         { 
			for(i = 0; i < polistbox.options.length; i++)
			{
				polistbox.options[i].selected = true;
			}						
		}
		var siinvlistbox=document.getElementById("settings_wktime_si_components");
		if(siinvlistbox != null)
         { 
			for(i = 0; i < siinvlistbox.options.length; i++)
			{
				siinvlistbox.options[i].selected = true;
			}						
		}
		
	});
	
	function validateDate(date)
	{
		var isDate=false;
		if(date !=null && date != "")
		{
			var rgx = /(\d{4})-(\d{2})-(\d{2})/;
			if(date.match(rgx))
				isDate=true;
		}
		return isDate;
	}
	
	function checkDuplicate(listbox, newValue)
	{
		isDuplicate = false;
		var listboxArr;
		
		for(i=0; i<listbox.options.length; i++)
		 {
			listboxArr=listbox.options[i].value.split('|');	
			if(newValue == listboxArr[0] && selectedIssue!=newValue)
			{
				isDuplicate=true;
			}
		 }		 
		 return isDuplicate;
	}
	
	function Sort(listboxId) {		
		var sortedList = $.makeArray($("#" + listboxId + " option"))
			.sort(function(a, b) {
				return $(a).text() < $(b).text() ? -1 : 1;
			});		
		$("#" + listboxId).empty().html(sortedList);
	}
	
	function projectChanged(prjDropdown,issueId){
		var id = prjDropdown.options[prjDropdown.selectedIndex].value;
		var fmt = 'text';
		var issueDD = document.getElementById("leave_issue");
		var $this = $(this);
		$.ajax({
			url: issueUrl,
			type: 'get',
			data: {format:fmt,project_id:id,issue_id:issueId},
			success: function(data){ updateIssueDD(data, issueDD,issueId); },
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading'); }
		});
	}

	function updateIssueDD(itemStr, dropdown, issueId)
	{
		var items = itemStr.split('\n');
		var i, index, val, text, start;
		dropdown.options.length = 0;
		for(i=0; i < items.length-1; i++){
			index = items[i].indexOf(',');
			start = 0;
			if(index != -1){
				val = items[i].substring(start, index);
				text = items[i].substring(index+1);
				dropdown.options[i] = new Option( 
					text, val, false);
			}
		}
		if(issueId<0){
			dropdown.selectedIndex = 0;
		}else{
			dropdown.value = issueId;
		}
	}
	
	function issueChanged(issueId){
		var fmt = 'text';
		var projectDD = document.getElementById("leave_project");
		var leaveIssue = document.getElementById("leave_issue");
		var projOptions= projectDD.options;
		var $this = $(this);
		$.ajax({
			url: projectUrl,
			type: 'get',
			data: {format:fmt,issue_id:issueId},
			success: function(data){
				var i, index, val, text, start;
				index = data.indexOf('|');
				start = 0;
				if(index != -1){
					val = data.substring(start, index);
					text = data.substring(index+1);
				}
				for (var i= 0;i<projOptions.length; i++) {
					if (projOptions[i].value===val) {
						projOptions[i].selected= true;
						break;
					}
				}
				if(!projectDD.options.selectedIndex >=0){
					projectDD.options[0] = new Option(text, val, false);
					projectDD.options[0].selected= true;
				}
				//projectDD.value = data;
				projectChanged(projectDD,issueId);
			},
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading');}
		});
	}
	
	function ValidateMinMaxHours(id, msg)
	{
		var maxhrfield = document.getElementById("settings_wktime_max_hour_day").value;
		var minhrfield = document.getElementById("settings_wktime_min_hour_day").value;		
		var maxhrdayrdb = document.getElementById("settings_wktime_restr_max_hour").checked ;
		var minhrdayrdb = document.getElementById("settings_wktime_restr_min_hour").checked ;
		var maxhrweekrdb = document.getElementById("settings_wktime_restr_max_hour_week").checked ;
		var minhrweekrdb = document.getElementById("settings_wktime_restr_min_hour_week").checked ;
		var maxhrweekfield = document.getElementById("settings_wktime_max_hour_week").value;
		var minhrweekfield = document.getElementById("settings_wktime_min_hour_week").value;
		if((Number(maxhrfield) < Number(minhrfield) && maxhrdayrdb && minhrdayrdb && Number(maxhrfield) > 0) || (Number(maxhrweekfield) < Number(minhrweekfield) && maxhrweekrdb && minhrweekrdb && Number(maxhrweekfield) > 0) )
		{
			document.getElementById(id).value = "";
			alert(msg);
			window.setTimeout(function ()
			{
				document.getElementById(id).focus();
			}, 0);
			
		}
	}
	
function listbox_moveacross(sourceID, destID) {
	var src = document.getElementById(sourceID);
	var dest = document.getElementById(destID);

	for(var count=0; count < src.options.length; count++) {

		if(src.options[count].selected == true) {
				var option = src.options[count];

				var newOption = document.createElement("option");
				newOption.value = option.value;
				newOption.text = option.text;
				newOption.selected = true;				
				try {
						 dest.add(newOption, null); //Standard
						 src.remove(count, null);
				 }catch(error) {
						 dest.add(newOption); // IE only
						 src.remove(count);
				 }
				count--;
		}
	}
}

function checked_modules(){
	if ($('.modules:checked').length == $('.modules').length){
		$(".checkall").prop('checked', true);
		$("#puncheckall").show();
		$("#pcheckall").hide();
	}
	else{
		$(".checkall").prop('checked', false);
		$("#puncheckall").hide();
		$("#pcheckall").show();
	}
}