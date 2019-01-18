var warnMsg;
var hasEntryError = false;
var hasTrackerError = false;
var spentTypeVal;

$(document).ready(function(){
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
		var spentTypeHF = '<input type="hidden" name="spent_type" id="spent_typeHF" value="">'
	}
			
	if(document.querySelector("h2") && document.querySelector("h2").innerHTML == "Spent time")	
	{
		if(document.getElementById('spent_type') == null)
		{	
			$("#query_form_content").append(spentTypeDD);
			$("#csv-export-form").append(spentTypeHF);
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
	$(".time-entries.selected,.icon.icon-reload").click(function(){
		sessionStorage.clear();
	});
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
	$("#spent_typeHF").val(spcheck);
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