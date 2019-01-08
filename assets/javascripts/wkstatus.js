var warnMsg;
var hasEntryError = false;
var hasTrackerError = false;
var spentTypeVal;

$(document).ready(function(){
	checkOrNotClockState = $('#check_clock_state_by_interval').val();
	if(checkOrNotClockState == 'true'){
			clockStateInterval = $('#clockstate_check_interval').val()
		if (clockStateInterval.match(/^\d+$/) !== null) {
			clockStateInterval = Number(clockStateInterval.match(/^\d+$/)[0]) * 1000;
		} else {
			clockStateInterval = 60000
		}
		setInterval(checkClockStateWkStatus, clockStateInterval);
	}
	var txtEntryDate;
	var txtissuetracker;
	var timeWarnMsg = document.getElementById('label_time_warn');
	var issueWarnMsg = document.getElementById('label_issue_warn');
	
	$('#quick-search').append( $('<br>') );	
	$('#quick-search').append( $('#appendlabel') );	
	$('#quick-search').append( $('#startdiv') ); 
	$('#quick-search').append( $('#enddiv') );
	
	if(document.getElementById('spent_type') == null)
	{
		var spentTypeDD = '<table><tr><td><label for="select" style="text-transform:   none;">Spent Type</label></td>'
            +'<td><select name="spent_type" id="spent_type" onchange="spentTypeValue(this);">'           
            +'</select></td></tr></table>';
	}
			
	if(document.querySelector("h2") && document.querySelector("h2").innerHTML == "Spent time")	
	{
		if(document.getElementById('spent_type') == null)
		{	
			$("#query_form_content").append(spentTypeDD);
		}
		var spentDD = document.getElementById('spent_type');
		var userid = document.getElementById('spent_time_user_id').value;
		var spentDDUrl = document.getElementById('getspenttype_url').value;	
		var $this = $(this);
		if(document.getElementById('spent_type') != null)
		{
			var ddloption =  document.getElementById('spent_type').options;			
			if(ddloption.length == 0)
			{
				$.ajax({
				url: spentDDUrl,
				type: 'get',
				data: {type: 'spentType'},
				success: function(data){ updateUserDD(data, spentDD, userid, false, false, "");},
				beforeSend: function(){ $this.addClass('ajax-loading'); },
				complete: function(){ spentTypeSelection(); $this.removeClass('ajax-loading'); }	      
				});
			}
		}			
	}
	else {
		sessionStorage.clear();
	}
	
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

function spentTypeValue(elespent)
{
	 spentTypeVal = elespent.options[elespent.selectedIndex].value;
	 sessionStorage.setItem("spent_type", spentTypeVal);
	 document.getElementById("query_form").submit();
}

function spentTypeSelection()
{
	var spcheck = sessionStorage.getItem("spent_type") == null ? "T" : sessionStorage.getItem("spent_type");
	if(document.getElementById('spent_type') != null) {
		var ddl = document.getElementById('spent_type');
		var opts = ddl.options.length;
		for (var i=0; i<opts; i++){
			if (ddl.options[i].value == spcheck){
				ddl.options[i].selected = true;
				break;
			}
		}
	}
}

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

function signAttendance(str)
{
	var d = new Date();
	var hh = d.getHours();
	var mm = d.getMinutes();
	elementhour = hh + ":" + mm;
	var datevalue = d;
	var clockState = false;
	if( str == 'start' )
	{
		clockState = true;
		document.getElementById('clockin' ).style.display = "none";
		document.getElementById('clockout').style.display = "block";
	}
	else
	{
		clockState = false;
		document.getElementById('clockin' ).style.display = "block";
		document.getElementById('clockout').style.display = "none";
	}
	var clkInOutUrl = document.getElementById('clockinout_url').value;	
	$.ajax({	
	url: clkInOutUrl,//'/updateClockInOut',
	type: 'get',
	data: {startdate : datevalue, str: clockState},
	success: function(data){ }   
	});
}

function checkClockStateWkStatus()
{
	var clockStateUrl = $("#clockstate_url").val();
	$.ajax({	
	url: clockStateUrl,
	type: 'get',
	success: function(data)
	{
		var clockIn = document.getElementById('clockin');
		var clockOut = document.getElementById('clockout');
		if (data === "clockOn" && clockOut.style.display === "none") {
			clockOut.style.display = "block";
			clockIn.style.display = "none";
		} else if (data === "clockOff" && clockIn.style.display === "none") {
			clockOut.style.display = "none";
			clockIn.style.display = "block";
		}
	}   
	});
}
