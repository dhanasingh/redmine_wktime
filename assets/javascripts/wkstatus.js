var warnMsg;
var hasEntryError = false;
var hasTrackerError = false;

$(document).ready(function(){
	var txtEntryDate;
	var txtissuetracker;
	var timeWarnMsg = document.getElementById('label_time_warn');
	var issueWarnMsg = document.getElementById('label_issue_warn');
	
	$('#quick-search').append( $('<br>') );	
	$('#quick-search').append( $('#appendlabel') );	
	$('#quick-search').append( $('#startdiv') ); 
	$('#quick-search').append( $('#enddiv') );
	
	if (timeWarnMsg != null && issueWarnMsg != null) {
		warnMsg = [timeWarnMsg.value, issueWarnMsg.value];
	}
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
	if(txtEntryDate!=null){		
		showEntryWarning(txtEntryDate.value);
		txtEntryDate.onchange=function(){showEntryWarning(this.value)};	
	}
	if( txtissuetracker != null)
	{
		showIssueWarning(txtissuetracker.value);
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
});

function showEntryWarning(entrydate){
	var $this = $(this);				
	var divID = document.getElementById('divError');	
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

function showMessage(data,divID){
	var errMsg = "";
	var log_time_page = document.getElementById('log_time_page').value;
	if(data!=null && ('s'== data || 'a'== data || 'l'== data)){
		if (hasTrackerError) {
			errMsg = warnMsg[0] + "<br>" + warnMsg[1];
		}
		else {
			errMsg = warnMsg[0];
		}
		hasEntryError = true;
	}
	else {
		if (hasTrackerError) {
			errMsg = warnMsg[1];
		}
		hasEntryError = false;
	}

	if (errMsg != "") {	
		if(document.getElementById('time_entry_hours') != null)
		{
			document.getElementById('time_entry_hours').disabled = true;
		}
		divID.innerHTML = errMsg;
		if(log_time_page == "true") {
			$('input[type="submit"]').prop('disabled', true);
		}
		divID.style.display = 'block';
	}
	else {
		if(document.getElementById('time_entry_hours') != null)
		{
			document.getElementById('time_entry_hours').disabled = false;
		}
		
		if(log_time_page == "true") {
			$('input[type="submit"]').prop('disabled', false);
		}
		divID.style.display ='none';
	}
}

function showIssueWarning(issue_id){
	var $this = $(this);
	var divID = document.getElementById('divError');
	var trackerUrl = document.getElementById('getissuetracker_url').value;		
	divID.style.display ='none';
	$.ajax({
		data: 'issue_id=' + issue_id,
		url: trackerUrl,
		type: 'get',		
		success: function(data){ showIssueMessage(data, divID); },
		complete: function(){ $this.removeClass('ajax-loading'); }
	});	
}

function showIssueMessage(data,divID) {
	var log_time_page = document.getElementById('log_time_page').value;
	var errMsg = "";
	if (data == "false") {		
		if (hasEntryError) {
			errMsg = warnMsg[0] + "<br>" + warnMsg[1];
		}
		else {
			errMsg = warnMsg[1];
		}		
		hasTrackerError = true;		
	}
	else {
		if (hasEntryError) {
			errMsg = warnMsg[0];
		}
		hasTrackerError = false;		
	}	
	
	if (errMsg != "") {	
		if(document.getElementById('time_entry_hours') != null)
		{
			document.getElementById('time_entry_hours').disabled = true;
		}
		divID.innerHTML = errMsg;
		if(log_time_page == "true") {
			$('input[type="submit"]').prop('disabled', true);
		}
		divID.style.display = 'block';
	}
	else {
		if(document.getElementById('time_entry_hours') != null)
		{
			document.getElementById('time_entry_hours').disabled = false;
		}
		if(log_time_page == "true") {
			$('input[type="submit"]').prop('disabled', false);
		}
		divID.style.display = 'none';
	}
}
/*
function updateAttendance()
{
	var attnEntriesId, attnStartTime, attnEndTime, attnhours;
	var attnDayEntriesCnt = new Array();
	var paramval = "";
	var j;
	attnDayEntriesCnt = document.getElementById('attnDayEntriesCnt') != null ? document.getElementById('attnDayEntriesCnt').value : -1;
	for(j = 0; j < attnDayEntriesCnt ; j++)
	{
		
		attnEntriesId = document.getElementById('attnEntriesId'+ j);
		attnStartTime = document.getElementById('attnstarttime'+ j);
		attnEndTime = document.getElementById('attnendtime'+ j);					
		if (attnStartTime.defaultValue !=  attnStartTime.value  || attnEndTime.defaultValue !=  attnEndTime.value ) {						
			paramval += ( !attnEntriesId.value ? (( "|" + "" ) + "|") : (attnEntriesId.value + "|") ) +  (!attnStartTime.value ? "0:00" : attnStartTime.value)  + "|" + (!attnEndTime.value ? "0:00" : attnEndTime.value)  + ",";
			if(!attnStartTime.value && !attnEndTime.value)
			{
				document.getElementById('attnEntriesId'+ j).value = '';
			}
		}
		
	}
	var datevalue = document.getElementById('startdate').value;
	var userid = document.getElementById('user_id').value;
	var nightshift = false;
	var date = true;
	
	$.ajax({
	url: '/updateAttendance',
	type: 'get',
	data: {editvalue : paramval, user_id:userid, startdate : datevalue,  nightshift : nightshift, isdate : date},
	success: function(data){ },   
	});
}

*/
function signAttendance(str)
{
	var d = new Date();
	var hh = d.getHours();
	var mm = d.getMinutes();
	elementhour = hh + ":" + mm;
	var datevalue = d;
	if( str == 'start' )
	{
	  document.getElementById('clockin' ).style.display = "none";
	  document.getElementById('clockout').style.display = "block";
	}
	else
	{
	  document.getElementById('clockin' ).style.display = "block";
	  document.getElementById('clockout').style.display = "none";
	}
	var clkInOutUrl = document.getElementById('clockinout_url').value;	
	$.ajax({	
	url: clkInOutUrl,//'/updateClockInOut',
	type: 'get',
	data: {startdate : datevalue, str: str},
	success: function(data){ }   
	});
}
