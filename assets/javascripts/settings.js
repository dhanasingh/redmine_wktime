var holiDayAction="";
var invalidDate="";
var selectedDate="";
$(document).ready(function(){
	updateCustFldDD(document.getElementById('settings_wktime_enter_cf_in_row1'),'settings_wktime_enter_cf_in_row2');
	updateCustFldDD(document.getElementById('settings_wktime_enter_cf_in_row2'),'settings_wktime_enter_cf_in_row1');	
	dialogAction();	
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
	
	function removeSelectedValue()
	{
		var listbox=document.getElementById("settings_wktime_public_holiday");
		if(listbox != null && listbox.options.selectedIndex >= 0)
         { 				
			if (confirm(holidayAlertMsg))
			{
				//removes options from listbox			
				//listbox.remove(listbox.options.selectedIndex);
				var i;
				for(i=listbox.options.length-1;i>=0;i--)
				{
				if(listbox.options[i].selected)
				listbox.remove(i);
				}
			}			
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
			if(newValue == listboxArr[0].trim() && selectedDate!=newValue)
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
	
