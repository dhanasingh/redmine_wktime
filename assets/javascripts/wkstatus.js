$(document).ready(function(){
	var txtEntryDate;
	var txtissuetracker;

	if(document.getElementById('divError') != null){
		if(document.getElementById('time_entry_issue_id')!=null){
			txtissuetracker = document.getElementById('time_entry_issue_id');		
		}	
		if(document.getElementById('time_entry_spent_on')!=null){
			txtEntryDate = document.getElementById('time_entry_spent_on');	
		}
		else{
			//get current date
			var today = new Date();	
			today = today.getFullYear() + '-' + (today.getMonth()+1) + '-' + today.getDate();
			showEntryWarning(today);
		}		
	}	
	
	if( txtissuetracker != null)
	{
		showIssueWarning(txtissuetracker.value);
		var cnt = 0;
		//txtissuetracker.onblur=function(){showIssueWarning(this.value)};
		$("#time_entry_issue_id").change(function(event){
			var tb = this;
			event.preventDefault();						
			setTimeout(function() {
				var issId = document.getElementById('time_entry_issue_id').value;
				if(issId >= 0)
				{
					showIssueWarning(issId);
					return;					
				}
			}, 500);		
		});	
	}		
	if(txtEntryDate!=null){		
		showEntryWarning(txtEntryDate.value);
		txtEntryDate.onchange=function(){showEntryWarning(this.value)};
			
	}	
});

function showEntryWarning(entrydate){
	var $this = $(this);				
	var divID =document.getElementById('divError');	
	var statusUrl = document.getElementById('getstatus_url').value;		
	divID.style.display ='none';
	$.ajax({
		url: statusUrl,
		type: 'get',
		data: {startDate: entrydate},
		success: function(data){ showMessage(data,divID); },
		complete: function(){ $this.removeClass('ajax-loading'); }
	});		
}

function showIssueWarning(issue_id){
	var $this = $(this);
	var divID =document.getElementById('divError');
	var trackerUrl = document.getElementById('getissuetracker_url').value;		
	divID.style.display ='none';
	$.ajax({
		data: 'issue_id=' + issue_id,
		url: trackerUrl,
		type: 'get',		
		success: function(data){ showIssueMessage(data,divID); },
		complete: function(){ $this.removeClass('ajax-loading'); }
	});	
}
function showIssueMessage(data,divID)
{
		if(data == "true")
		{
			document.getElementById('lblissuetracker').style.display = 'none';
		}
		else
		{
			document.getElementById('lblissuetracker').style.display = 'inline-block';
		}
			
		if ($('#lbltimeentry').is(':visible')) {  	
			divID.style.display = 'none';
			$('input[type="submit"]').prop('disabled', false);
		}
		else
		{
			divID.style.display = 'block';
			document.getElementById("lblissuetracker").style.paddingLeft = "0px";
			$('input[type="submit"]').prop('disabled', true);
			if (!($('#lblissuetracker').is(':visible')) && !($('#lbltimeentry').is(':visible')) )
			{
				divID.style.display = 'block';
				$('input[type="submit"]').prop('disabled', true);
				if (!($('#lblissuetracker').is(':visible')))
				{
				divID.style.display = 'none';
				$('input[type="submit"]').prop('disabled', false);
				}		
			}	
		};	

		if(($('#lblissuetracker').is(':visible')) && ($('#lbltimeentry').is(':visible')))
		{
			document.getElementById("lblissuetracker").style.paddingLeft = "210px"; // warning msg alignment for issue
		}
		
	}

function showMessage(data,divID){	
	if (data!=null && ('s'== data || 'a'== data || 'l'== data)) {
		
		document.getElementById('lbltimeentry').style.display = 'inline-block';
	}
	else{				
		document.getElementById('lbltimeentry').style.display = 'none';
	}
	
	if (($('#lblissuetracker').is(':visible') )  ) 
	{   
		divID.style.display = 'none';
		$('input[type="submit"]').prop('disabled', false);
	}
	else
	{
		divID.style.display = 'block';
		$('input[type="submit"]').prop('disabled', true);		
	};
	
	if ( !($('#lblissuetracker').is(':visible')) && !($('#lbltimeentry').is(':visible')) ) 
	{
		divID.style.display = 'none'; // when current date is new hide the div
		$('input[type="submit"]').prop('disabled', false);
		if (data!=null && ('s'== data || 'a'== data || 'l'== data)) {
			divID.style.display = 'block'; // this loop when current date is submitted show warning msg
			$('input[type="submit"]').prop('disabled', true);
		}
	}
	
	if(($('#lblissuetracker').is(':visible')) && ($('#lbltimeentry').is(':visible')))
		{
		document.getElementById("lblissuetracker").style.paddingLeft = "210px"; // warning msg alignment for status
		}
		else
		{
			document.getElementById("lblissuetracker").style.paddingLeft = "0px";
		}
			
}
