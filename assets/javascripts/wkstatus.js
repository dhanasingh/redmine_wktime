var warnMsg;
var hasEntryError = false;
var hasTrackerError = false;
var spentTypeVal;
var myLongitude = 0;
var myLatitude = 0;

$(document).ready(function(){
	var txtEntryDate;
	var txtissuetracker;
	var timeWarnMsg = document.getElementById('label_time_warn');
	var issueWarnMsg = document.getElementById('label_issue_warn');

	$('#project-jump').after($('#clockINOUT'));
	$('#clockINOUT').click(function(){
		var name = $('#clockin').is(':visible') ? 'start' : 'end';
		signAttendance(name);
	});
	clockTitle = $('#clockin').is(':visible') ? 'Clock in' : 'Clock out';
	$("#clockINOUT").attr('title',clockTitle);

	if(document.getElementById('spent_type') == null)
	{
		var spentTypeDD = '<table><tr><td><label for="select" style="text-transform:   none;">Spent Type</label></td>'
            +'<td><select name="spent_type" id="spent_type" onchange="spentTypeValue(this);">'
            +'</select></td></tr></table>';
		var spentTypeHF = '<input type="hidden" name="spent_type" id="spent_typeHF" value="">'
	}

	if ($('.time-entries.selected').length > 0)
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
	// else {
	// 	sessionStorage.clear();
	// }

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
	// $(".time-entries.selected,.icon.icon-reload").click(function(){
	// 	sessionStorage.clear();
	// });

	//Time Tracking
		$("#project-jump").after($("#issueLog"));
	observeSearchfield('issues-quick-search', null, $('#issues-quick-search').data('automcomplete-url'));
	$('#issueLog span').on('click', function(){
		const clock_action = $('#g_clock_action').val();
		if(clock_action == 'S') $('#issue-content .quick-search').hide();
		const offSet = (new Date).getTimezoneOffset();
		projectID = $("#projectID").val();
		$.ajax({
			url: $('#issues-quick-search').data('automcomplete-url'),
			type: 'get',
			data: { q: '', project_id: projectID, type: clock_action == 'S' ? 'finish' : 'start', offSet: offSet },
			success:function(data){
				eval(data);
			}
		});
	});

	$(document).on('click', '.drdn-items.issues .issue_select', function(){
		save_issue_log(this);
	});

	$( '.drdn-items .unseen').click(function(){
		const id = $(this).data('id')
		var element = this;
		$.ajax({
			url: '/wknotification/update_user_notification?id='+id,
			type: 'get',
			success: function(){
				if ($(element).hasClass('unseen')) {
					$(element).removeClass('unseen').addClass('seen');
				}
			}
		});
	});

	//Notification
	$("#project-jump").after($("#notification"));
	$("#notification").attr('title','notification');

	//mark read notification
	$('#mark_read').click(function(){
		url = "/wknotification/mark_read_notification";
		$.ajax({
			url: url,
			type: 'post',
			success: function(data){ },
			complete: function(){ $('.drdn.expanded').removeClass('expanded'); }
		});
	});
});

function spentTypeValue(elespent)
{
	//  spentTypeVal = elespent.options[elespent.selectedIndex].value;
	//  sessionStorage.setItem("spent_type", spentTypeVal);
	 document.getElementById("query_form").submit();
}

function spentTypeSelection()
{
	// const spent_type = (new URL(window.location.href)).searchParams.get("spent_type");
	// var spcheck = sessionStorage.getItem("spent_type") == null ? (spent_type ? spent_type : "T") : sessionStorage.getItem("spent_type");
	var spcheck = $('#spentTypeSession').val();
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
  var offSet = d.getTimezoneOffset();
	if( str == 'start' )
	{
		$('#clockin').hide();
		$('#clockout').show();
	  $("#clockINOUT").prop('title','Clock out');
	}
	else
	{
		$('#clockin').show();
		$('#clockout').hide();
	  $("#clockINOUT").prop('title','Clock in');
	}
	var clkInOutUrl = document.getElementById('clockinout_url').value;
	var data = { startdate : datevalue, str: str, offSet: offSet };
	// Sending Geolocation params
	if(myLatitude && myLongitude){
		data['latitude'] = myLatitude;
		data['longitude'] = myLongitude;
	}
	$.ajax({
		url: clkInOutUrl,
		type: 'post',
		data: data,
		success: function(data){ }
	});
}

function save_issue_log(ele){
	let date = new Date();
	const offSet = date.getTimezoneOffset();
	const clock_action = $('#g_clock_action').val();
	let key = clock_action != 'S' ? 'issue_id' : 'id'
	let data = {offSet: offSet, [key]: ele.id};

	if(myLatitude && myLongitude){
		data['latitude'] = myLatitude;
		data['longitude'] = myLongitude;
	}
	$.ajax({
		url: '/wkbase/save_issue_log',
		type: 'get',
		data: data,
		success: function(resMsg){
			if(resMsg == 'finish'){
				$('#issueImg img').prop('src','/plugin_assets/redmine_wktime/images/finish.png');
				$('#g_clock_action').val('S');
			}
			else if(resMsg == 'start'){
				$('#issueImg img').prop('src','/plugin_assets/redmine_wktime/images/start.png');
				$('#issue-content .quick-search').show();
				$('#g_clock_action').val('');
			}
			else{
				alert(resMsg)
			}
		},
		complete: function(){ $('.drdn.expanded').removeClass('expanded'); }
	});

}