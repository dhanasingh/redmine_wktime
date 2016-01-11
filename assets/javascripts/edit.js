//jquery code for the comment dialog

var comment_row = 1;
var comment_col = 1;
var cf_types = "";
var cf_ids = "";
var wkcf_ids ="";
var editUrl = "";
var showWorkHeader = false;
var allowBlankIssue = false;
var commentInRow = false;
var footerRows = 1;
var headerRows = 1;
var hStartIndex = 2;
var issueField = 'Issue';
var submissionack="";
var minHourAlertMsg="";
var decSeparator = ".";
var lblPleaseSelect = "";
var lblWarnUnsavedTE = "";
var breakarray =  "";
var st,ed;
$(document).ready(function() {
//$(function() {
	var e_comments = $( "#_edit_comments_" );
	var e_notes = $( "#_edit_notes_" );
	 $( "#clockInOut-dlg" ).dialog({
		autoOpen: false,
	//	resizable: false,
		modal: false,
		width:'280',
		height: '300',
        overflow: 'auto', /* Or scroll, depending on your needs*/
   // width: 300px;
		buttons: {
			"Ok": function() {
				var elementid;
				var startvalue,endvalue,textlength, newstartval, newendval,datevalue, userid,diff, newdiff;
				var paramval = "";
				textlength = document.getElementById('textlength').value;
				for(i=0; i <= textlength ; i++)
				{
					startvalue = document.getElementById('popupstart_'+i);
					endvalue = document.getElementById('popupend_'+i);
					diff = document.getElementById('total_'+i);
					elementid = document.getElementById('hiddenpopup_'+i);
					if(startvalue || endvalue)
					{
						if (startvalue.defaultValue !=  startvalue.value  || endvalue.defaultValue !=  endvalue.value ) {
						paramval += elementid.value + "|" +  startvalue.value + "|" + endvalue.value + "|" + diff.value + ",";						
					}
					}					
				}				
				for(i=0; i < 7; i++)
				{
					newstartval = document.getElementById('newstart_'+i);
					newendval = document.getElementById('newend_'+i);
					newdiff = document.getElementById('newdiff_'+i);
					if(newstartval || newendval)
					{
						if (newstartval.defaultValue !=  newstartval.value  || newendval.defaultValue !=  newendval.value ) {
						paramval += "|" + i + "|" +  newstartval.value + "|" + newendval.value + "|" + newdiff.value + ",";						
					}
					}
				}
				datevalue = document.getElementById('startday').value;
				userid = document.getElementById('user_id').value;
				$.ajax({
					url: 'updateAttendance',
					type: 'get',
					data: {editvalue : paramval, startdate : datevalue, user_id : userid},
					success: function(data){  },  
					//complete: function(){ $this.removeClass('ajax-loading'); }
				});		
				$( this ).dialog( "close" );
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	

	$( "#comment-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: false,
		buttons: {
			"Ok": function() {
					var edits = $('img[name="custfield_img'+comment_row+'[]"]');
					var comments = $('input[name="comments'+comment_row+'[]"]');
					var custFldToolTip;
					if(!commentInRow){
						comments[comment_col-1].value = e_comments.val();	
					}					
					updateCustomField();					
					custFldToolTip = getCustFldToolTip();
					if(	!commentInRow && e_comments.val() != "")
					{
						edits[comment_col-1].title = e_comments.val() + "," +custFldToolTip;
						
					}
					else
					{
						edits[comment_col-1].title = custFldToolTip;
						
					}
					//show detail popup dialog ok button to change image 					
					var x = document.getElementsByName("custfield_img"+comment_row+"[]");
					if( (e_comments.val() != "" || custFldToolTip)  && (!commentInRow  || custFldToolTip )   ) 
					{						
						$(x[comment_col-1]).attr({src: "../plugin_assets/redmine_wktime/images/withcommant.png"});
						
					}
					else
					{					
						$(x[comment_col-1]).attr({src: "../plugin_assets/redmine_wktime/images/withoutcommant.png"});
					}					
					$( this ).dialog( "close" );				
					//unregister this event since this is showing a 'don't leave' message
					//loosk like this is not supported in Opera
					//window.onbeforeunload = null;
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	
	
	$( "#notes-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: true,
		buttons: {
			"Ok": function() {
				$( this ).dialog( "close" );
				$( "#hidden_wk_reject" ).val('r');
				$( "#wktime_notes" ).val(e_notes.val());
				$("#wktime_edit").submit();
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	
	
	//when initially load the page hidden the clock in Clock out button
	var imgend,imghide,imgstart;
	if(document.getElementById('imgdisable') != null)
	{
		imghide = document.getElementById('imgdisable').value;
		imghide++;
		if(document.getElementById('end_'+imghide) != null)
		{
		imgend = document.getElementById('end_'+imghide).value;
		}
		if(document.getElementById('start_'+imghide) != null)
		{
		imgstart = document.getElementById('start_'+imghide).value;
		}
		if( imgend == "00:00" && imgstart != "00:00" )
		{
			document.getElementById('end_img').style.visibility = "visible";
			document.getElementById('start_img').style.visibility = 'hidden';
		}
		else
		{
			document.getElementById('end_img').style.visibility = 'hidden';
		}
	}
	
	
	// when initially load the page update total and remaininghours
    for(i = 1; i <= 7; i++)
	{		
		updateRemainingHr(i);	
		updateTotalHr(i);
	}
	
	//when initially load the page update the dialog box total
	var textlength;
	var paramval = "";
	textlength = document.getElementById('textlength').value;
	for(i=0; i < textlength ; i++)
	{
		hoursClockInOut(1,i);
	}
	
	totalClockInOut();
	//calculatebreakTime()
	//calculatebreakTime();
	
});

$(window).load(function(){
	warnLeavingUnsavedTE(lblWarnUnsavedTE); 
});

var warnLeavingUnsavedTEMsg;
function warnLeavingUnsavedTE(message) {
  warnLeavingUnsavedTEMsg = message;
  $(document).on('submit', 'form', function(){
    $('textarea').removeData('changed');
    $('input').removeData('changed');
    $('select').removeData('changed');
  });
  setElementData('textarea');
  setElementData('input');
  setElementData('select');
  window.onbeforeunload = function(){
	var warn = (isChanged('textarea') || isChanged('input') || isChanged('select'));
    if (warn) {return warnLeavingUnsavedTEMsg;}
  };
}

function setElementData(elType) {
  $(document).on('change', elType, function(){
    $(this).data('changed', 'changed');
  });
}

function isChanged(elType) {
    var warn = false;
    $(elType).blur().each(function(){
      if ($(this).data('changed')) {
        warn = true;
      }
    });
	return warn;
}

function showComment(row, col) {
	var images = $( 'img[name="custfield_img'+row+'[]"]' );
	var width = 300;
	var height = 350;
	var posX = 0;
	var posY = 0;
	var i = row - 1;
	var currImage = images[col-1];
	var projDropdowns = $('select[name="time_entry[][project_id]"]');
	var issDropdowns = $('select[name="time_entry[][issue_id]"]');
	var actDropdowns = $('select[name="time_entry[][activity_id]"]');
	var enterIssueIDChkBox = $('input[name="enter_issue_id"]');
	//set the row which is modified
	comment_row = row;
	comment_col = col;
	if(!commentInRow){
		var comments = $('input[name="comments'+row+'[]"]');
		$( "#_edit_comments_" ).val(comments[col-1].value);
	}
	if(enterIssueIDChkBox && $(enterIssueIDChkBox).is(':checked')){
		var issueIds = $('input[name="time_entry[][issue_id]"]');
		//issue will be a text box
		$( "#_edit_comm_iss_" ).html(issueIds[i].value);
	}else{
		$( "#_edit_comm_proj_" ).html(projDropdowns[i].selectedIndex >= 0 ? 
			projDropdowns[i].options[projDropdowns[i].selectedIndex].text : '');			
		$( "#_edit_comm_iss_" ).html(issDropdowns[i].selectedIndex >= 0 ?
			(issDropdowns[i].options[issDropdowns[i].selectedIndex].value == -1 ? '' : issDropdowns[i].options[issDropdowns[i].selectedIndex].text) : '');
	}
	$( "#_edit_comm_act_" ).html(actDropdowns[i].selectedIndex >= 0 ?
		(actDropdowns[i].options[actDropdowns[i].selectedIndex].value == -1 ? '' : actDropdowns[i].options[actDropdowns[i].selectedIndex].text) : '');
	
	showCustomField();		
	
	posX = $(currImage).offset().left - $(document).scrollLeft() - width + $(currImage).outerWidth();
	posY = $(currImage).offset().top - $(document).scrollTop() + $(currImage).outerHeight();
	$("#comment-dlg").dialog({width:width, height:height ,position:[posX, posY]});
	$( "#comment-dlg" ).dialog( "open" );
}

function showNotes() {
	var rejectBtn = $( 'input[name="wktime_reject"]' );
	var width = 300;
	var height = 200;
	var posX = 0;
	var posY = 0;
	posX = $(rejectBtn).offset().left - $(document).scrollLeft() - width + $(rejectBtn).outerWidth();
	posY = $(rejectBtn).offset().top - $(document).scrollTop() + $(rejectBtn).outerHeight();
	$("#notes-dlg").dialog({width:width, height:height ,position:[posX, posY]});
	$( "#notes-dlg" ).dialog( "open" );
	//return false so the form is not posted
	return false;
}

function showCustomField() {
	if(cf_ids != ''){
		var cust_fids = cf_ids.split(',');
		var i, cust_field, ck_cust_field, custom_fields, cust_vals;
		for(i=0; i < cust_fids.length; i++){
			cust_field = $( "#" + cust_fids[i]);
			custom_fields = $('input[name="'+cust_fids[i]+comment_row+'[]"]');
			
			if(cust_field.is("select")){
				//if the value is not set, it could be an array
				cust_vals = custom_fields[comment_col-1].value.split(',');
				cust_field.val(cust_vals);
			}else if(cust_field.attr('type') == "hidden"){
				//the checkbox also has a hidden field
				ck_cust_field = $('input[id="'+cust_fids[i]+'"][type="checkbox"]');
				ck_cust_field.attr('checked', custom_fields[comment_col-1].value == 1);
			}else if(cust_field.attr('type') == "checkbox"){
				cust_field.attr('checked', custom_fields[comment_col-1].value == 1);
			}else{
				cust_field.val(custom_fields[comment_col-1].value);
			}
		}
	}
}

function updateCustomField() {

	if(cf_ids != ''){
		var cust_fids = cf_ids.split(',');
		var i, j,cust_field, ck_cust_field, custom_fields;
		
		for(i=0; i < cust_fids.length; i++)
		{		
			cust_field = $( "#" + cust_fids[i]);
			custom_fields = $('input[name="'+cust_fids[i]+comment_row+'[]"]');
			if(cust_field.attr('type') == "hidden"){
				//the checkbox also has a hidden field
				ck_cust_field = $('input[id="'+cust_fids[i]+'"][type="checkbox"]');
				if(ck_cust_field.is(':checked')){
					custom_fields[comment_col-1].value = 1;
				}else /*if(custom_fields[comment_col-1].value != "")*/{
					//set it to 0 only if it is not empty
					custom_fields[comment_col-1].value = 0;
				}
				cust_field.val(custom_fields[comment_col-1].value);
			}else{
				custom_fields[comment_col-1].value = cust_field.val();
			}
		}		
	}
	
}

//forming custom fields for tooltip
function getCustFldToolTip()
{
	var cusfield = "",str;
	if(cf_ids != '')
	{	
		var cust_fids = cf_ids.split(',');		
		for(i=0; i < cust_fids.length; i++)
		{		
			cust_field = $( "#" + cust_fids[i]);
			if (cusfield == "")
			{
				str = "";
			}
			else
			{
				str=",";
			}
			if(cust_field.val() != null && cust_field.val() !="")
			{
					cusfield += str + cust_field.val();
					str=",";
			}
		}
	}
	return cusfield;
}

function projectChanged(projDropdown, row){
	
	var issuId = document.getElementById('enter_issue_id');
	
	if((issuId==null)||(issuId != null && !issuId.checked))
	{	
		var id;
		if(row != 0){	
			id = projDropdown.options[projDropdown.selectedIndex].value;
		}
		else{
			//click addrow, changed issues for particular project tracker
			row = projDropdown.length;	
			var id =projDropdown[row-1].value;			
		}
		var fmt = 'text';
		var issDropdown = document.getElementsByName("time_entry[][issue_id]");
		var actDropdown = document.getElementsByName("time_entry[][activity_id]");
		var issUrl = document.getElementById("getissues_url").value;
		var actUrl = document.getElementById("getactivities_url").value;
	 
		var uid = document.getElementById("user_id").value;
		var $this = $(this);    
		issue_assign_user=issueAssignUser();
		var	trackerListArr = getSelectedTracker(document.getElementById('select_issues_tracker'));	
		var startday=document.getElementById("startday").value;
		$.ajax({
			url: issUrl,
			type: 'get',
			data: {project_id: id, user_id: uid,tracker_id: trackerListArr, format:fmt,startday:startday, issue_assign_user: issue_assign_user},
			success: function(data){
				var items = data.split('\n');
				var needBlankOption = items.length-1 > 1 || allowBlankIssue ;
				updateDropdown(data, row, issDropdown, true, needBlankOption, true, null); 
			},
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading'); }
		});
		$.ajax({
			url: actUrl,
			type: 'get',
			data: {project_id: id, user_id: uid, format:fmt},
			success: function(data){
				var actId = getDefaultActId(data);
				var items = data.split('\n');
				var needBlankOption = !(items.length-1 == 1 || actId != null);
				updateDropdown(data, row, actDropdown, false, needBlankOption, true, actId);
			},
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading'); }
		});
	}
}

function trackerFilterChanged(trackerList){
	if(trackerList!=null){	
		var projDropdown = document.getElementsByName('time_entry[][project_id]');		
		var fmt = 'text';		
		var issUrl = document.getElementById("getissues_url").value;	
		var uid = document.getElementById("user_id").value;
		var $this = $(this);
		issue_assign_user=issueAssignUser();
		var startday=document.getElementById("startday").value;
		//get selected tracter id from listbox and form array			
		var trackerListArr = getSelectedTracker(trackerList);
		var projIds = new Array();	
		var i,b = {},projectids = [];
		//if selectd project list
		for(i=0; i < projDropdown.length;i++)
		{	
			projIds[i] = projDropdown[i].value;			
		}		
		//remove duplicate value from array
		for (i = 0; i < projIds.length; i++) {
			b[projIds[i]] = projIds[i];
		}		
		
		for (var key in b) {
			projectids.push(key);
		}
	
		$.ajax({
			url: issUrl,
			type: 'get',
			data: {project_ids:projectids,user_id: uid, tracker_id: trackerListArr, format:fmt,startday:startday, issue_assign_user: issue_assign_user},			
			success: function(data){updateIssDropdowns(data,projDropdown,projectids); },
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading'); }
		});
	}	
}

function getSelectedTracker(trackerList){
	var trackerListArr;
	if(trackerList != null)
	{
		trackerListArr = new Array();
		var j=0;
		for(var i=0; i < trackerList.options.length; i++)
		{ 	
			if(trackerList.options[i].selected == true && trackerList.options[i].value != "") 
			{ 
				trackerListArr[j] = trackerList.options[i].value;
				j++;				
			}
		}
	}
	return trackerListArr;
}


function issueChanged(issueText, row){
	var id = myTrim(issueText.value);
	issueIdChanged(id, row);
}
	
function issueIdChanged(id, row){
	if(id != ''){
		var fmt = 'text';
		var actDropdown = document.getElementsByName("time_entry[][activity_id]");
		var actUrl = document.getElementById("getactivities_url").value;

		var uid = document.getElementById("user_id").value;

		var $this = $(this);
		$.ajax({
			url: actUrl,
			type: 'get',
			data: {issue_id: id, user_id: uid, format:fmt},
			success: function(data){ updateActDropdown(data, row, actDropdown);},
			error: function(jqXHR, textStatus, errorThrown){
				alert(issueField + ' ' + id + ' ' + errorThrown);
			},
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading'); }
		});
	}
}

function updateIssDropdowns(itemStr, projDropdowns,projIds)
{	
	var items = itemStr.split('\n');
	var i, index, itemStr2='', val, text;
	var prev_project_id=0, project_id=0;
	var j, id;	
	var issDropdowns = document.getElementsByName("time_entry[][issue_id]");	
	
	for(i=0; i < items.length-1; i++){	
		index = items[i].indexOf('|');		
		if(index != -1){
			project_id = items[i].substring(0, index);
			
			//if project_id exists in projIds array, remove project_id from array
			for(j=0; j<= projIds.length; j++){			
				if(project_id == projIds[j]){				
					projIds.splice(j,1);
				}				
			}
			if(prev_project_id != project_id && itemStr2 != ''){		
				updateIssueDD(itemStr2, prev_project_id, projDropdowns, issDropdowns);
				itemStr2='';
			}
			itemStr2 += items[i] + '\n';		
			prev_project_id = project_id;
		}
	}
	//the last project needs to be updated outside the loop
	updateIssueDD(itemStr2, prev_project_id, projDropdowns, issDropdowns);	
	
	//tracker is empty for project ,set option value empty
	if(projIds.length >0)
	{
		for(k=0; k < projIds.length; k++){		
			updateIssueDD("", projIds[k], projDropdowns, issDropdowns);
		}
	}
}

function updateIssueDD(itemStr, project_id, projDropdowns, issDropdowns)
{
	var proj_id, issue_id=null;
	var items = itemStr.split('\n');
	var needBlankOption = items.length-1 > 1 || allowBlankIssue ;
	if(projDropdowns){	
		for (j=0; j < projDropdowns.length; j++){		
			proj_id = projDropdowns[j].options[projDropdowns[j].selectedIndex].value;
			if(proj_id != '' && project_id == proj_id){			
				if(issDropdowns[j]){
					if(issDropdowns[j].value != ""){						
						issue_id = issDropdowns[j].options[issDropdowns[j].selectedIndex].value;
					}	
					else {
						issue_id = null;
					}
					updateDropdown(itemStr, j+1, issDropdowns, true, needBlankOption, true, issue_id);
				}
			}
		}
	}
}
function updateActDropdown(data, row, actDropdown){
	
	var enterIsueIdChk = document.getElementById("enter_issue_id");
	var items = data.split('\n');
	if(enterIsueIdChk && enterIsueIdChk.checked){
		//set the project id
		var projectIdHFs = document.getElementsByName("time_entry[][project_id]");
		//var items = data.split('\n');
		var index;
		if(items.length > 0){
			index = items[0].indexOf('|');
			if(index != -1){
				//set the project id
				projectIdHFs[row-1].value = items[0].substring(0, index);
			}
		}
	}
	var actId = getDefaultActId(data);
	//var items = data.split('\n');
	var needBlankOption = !(items.length-1 == 1 || actId != null);
	updateDropdown(data, row, actDropdown, false, needBlankOption, true, actId);
}

function updateDropdown(itemStr, row, dropdown, showId, needBlankOption, skipFirst, selectedVal)
{
	var items = itemStr.split('\n');
	var selectedValSet = false;
	var selectedText = "";
	if (selectedVal) {
		selectedText = dropdown[row-1].options[dropdown[row-1].selectedIndex].text;
	}
	dropdown[row-1].options.length = 0;
	if(needBlankOption){
		if (showId && allowBlankIssue){
			dropdown[row-1].options[0] = new Option( "", "", false, false);
		}else{
			dropdown[row-1].options[0] = new Option( "---" + lblPleaseSelect + "---", "-1", false, false);
		}
	}
	var i, index, val, text, start;
	for(i=0; i < items.length-1; i++){
		index = items[i].indexOf('|');
		if(skipFirst){
			if(index != -1){
				start = index+1;
				index = items[i].indexOf('|', index+1);
			}
		}else{
			start = 0;
		}
		if(index != -1){
			val = items[i].substring(start, index);
			text = items[i].substring(index+1);
			//if(showId)
			//{
				text = text.split('|');
			//}
			dropdown[row-1].options[needBlankOption ? i+1 : i] = new Option( 
				showId ? text[0] + ' #' + val + ': ' + text[1] : text[1], val, false, val == selectedVal);			
			if(val == selectedVal){
				selectedValSet = true;
			}
		}
	}
	
	var addExistingOption = true;
	if(showId) { //for issue dropdown
		var hoursFld = document.getElementsByName("hours" + row + "[]");
		addExistingOption = false;
		for(var j = 0; j < hoursFld.length; j++) {
			if(hoursFld[j].value) {
				addExistingOption = true;			
				break;
			}
		}
	}
	if (addExistingOption === true) {
		if(selectedVal && !selectedValSet){
			dropdown[row-1].options[needBlankOption ? i+1 : i] = new Option(selectedText, selectedVal, false, true);
		}
	}
}

function performAction(url)
{
	document.wktime_edit.action = url;
	document.wktime_edit.submit();
}

/* allows user to enter issue as id and issue assigned to me */
function enterIssueIdorAssignUser(){
	var uid = document.getElementById("user_id").value;
	var startday = document.getElementById("startday").value;
	var enterIsueIdChk = document.getElementById("enter_issue_id");
	var IsueassignUserChk = document.getElementById("issue_assign_user");
	var trackerList = document.getElementById('select_issues_tracker');	
	var issueID="";
	var issueAssignUser="";
	if(enterIsueIdChk && enterIsueIdChk.checked){
		issueID = "&enter_issue_id=" + enterIsueIdChk.value;
	}
	if(IsueassignUserChk && IsueassignUserChk.checked){		
		issueAssignUser = "&issue_assign_user=" + IsueassignUserChk.value;
	}
	if (trackerList && IsueassignUserChk){
		var trackerListArr = getSelectedTracker(trackerList);
		if(trackerListArr){
			issueAssignUser += "&tracker_ids=" +trackerListArr;
		}
	}
		location.href = editUrl +issueID + issueAssignUser;
	

}

function addRow(){
	var issueTable = document.getElementById("issueTable");	
	var saveButton = document.getElementById("wktime_save");
	var submitButton = document.getElementById("wktime_submit");
	var	issueTemplate = document.getElementById("issueTemplate");
	var rowCount = issueTable.rows.length;	
	//there is a header row and a total row present, so the empty count is 2
	var row = issueTable.insertRow(rowCount - footerRows);
	
	var cellCount = issueTemplate.rows[0].cells.length;
	var i, cell;
	for(i=0; i < cellCount; i++){
		cell = row.insertCell(i);
		cell.innerHTML = issueTemplate.rows[0].cells[i].innerHTML.replace(/__template__/g, '');
		cell.className = issueTemplate.rows[0].cells[i].className;
		cell.align = issueTemplate.rows[0].cells[i].align;
	}
	renameElemProperties(row, 0, rowCount- (headerRows + footerRows - 1));
	saveButton.disabled = false;
	if(submitButton!=undefined)
	{
		submitButton.disabled = false;
	}
}

function deleteRow(row, deleteMsg){
	
	//IE7 doesn't pull up the new elements by getElementsByName
	//var ids = document.getElementsByName("ids" + row + "[]");
	//var hours = document.getElementsByName("hours" + row + "[]");		
	
	var issueTable = document.getElementById("issueTable");
	//since there is already a header row
	var hours = myGetElementsByName(issueTable.rows[row+headerRows-1], "input","hours" + row + "[]");
	var ids = myGetElementsByName(issueTable.rows[row+headerRows-1], "input","ids" + row + "[]");			
	var rowTotal = 0.0;
	var uid = document.getElementById("user_id");
	var vals = new Array();
	var days = new Array();
	var i = 0, j = 0;
	var fmt = 'text', val;
	var url = document.getElementById("deleterow_url").value;
	
	for(i=0; i< ids.length; i++){
		if (ids[i].value != ''){
			vals[j] = ids[i].value;
			j++;
		}
	}
	
	j = 0;
	for(i=0; i< hours.length; i++){
		val = myTrim(hours[i].value);
		//replace any . with . for internationalization
		val = val.replace(decSeparator, '\.');
		if( val != '' && !isNaN(val)){
			days[j] = i+1;
			j++;
		}
	}
	if (vals.length > 0){
		var $this = $(this);
		$.ajax({
			url: url,
			type: 'get',
			data: {'ids[]': vals, format:fmt, user_id:uid.value},
			success: function(data){ postDeleteRow(data, row, days, deleteMsg); },
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading'); }
		});
	
	}
	else
	{
		postDeleteRow('OK', row, days);
	}
}

function postDeleteRow(result, row, days, deleteMsg){

	var issueTable = document.getElementById("issueTable");
	var saveButton = document.getElementById("wktime_save");
	var submitButton = document.getElementById("wktime_submit");
	var rowCount = issueTable.rows.length;
	var i, dayTotal = 0.0;
	
	//there is a header and a total row always present, so the empty count is 2
	if(result == "OK"){
		//replaee the rows following the deleted row
		for(i=row+headerRows; i < rowCount-footerRows; i++){
			//replace inner html is not working properly for delete so modify
			// the existing DOM objects
			
			renameElemProperties(issueTable.rows[i], i-(headerRows-1), i-headerRows);
		}
		
		issueTable.deleteRow(row+headerRows-1);
		if(rowCount - (headerRows + footerRows - 1) <= 2){
			saveButton.disabled = true;
			if(submitButton!=undefined)
			{
				submitButton.disabled = true;
			}
		}
		for(i=0; i < days.length; i++){	
			dayTotal = calculateTotal(days[i]);
			updateDayTotal(days[i], dayTotal);
			if(showWorkHeader){
				updateRemainingHr(days[i]);
			}
		}
	}else{
		alert(deleteMsg);
	}
}

//replace inner html is not working properly, hence decided to
//do the rename proeprties
function renameElemProperties(row, index, newIndex){
	var cellCount = row.cells.length;
	var i;
	for(i=0; i < cellCount; i++){
		renameCellIDs(row.cells[i], index, newIndex);
	}
	row.className = (newIndex+1)%2 ? "time-entry odd" : "time-entry even";
}

function renameCellIDs(cell, index, newIndex){
	
	renameProperty(cell, 'input', 'hours', index, newIndex);
	renameProperty(cell, 'input', 'ids', index, newIndex);
	renameProperty(cell, 'input', 'disabled', index, newIndex);
	renameProperty(cell, 'input', 'comments', index, newIndex);
	renameProperty(cell, 'img', 'custfield_img', index, newIndex);
	
	if(cf_ids != ''){
		var cust_fids = cf_ids.split(',');
		var i, j, cust_field, custom_fields;
		for(i=0; i < cust_fids.length; i++){
				renameProperty(cell, 'input', cust_fids[i], index, newIndex);
		}
	}

	// '(' is a meta special character, so it needs escaping '\'
	// since '\' is inside quotes, you need another '\'
	renameProperty(cell, 'select', '', index, newIndex);
	renameProperty(cell, 'a', '', 'javascript:deleteRow\\(' + index,
		'javascript:deleteRow(' + newIndex);
	renameProperty(cell, 'a', '', 'javascript:showComment\\(' + index,
		'javascript:showComment(' + newIndex);
}

function renameProperty(cell, tag, prefix, str, newStr){
	var j;
	var children = cell.getElementsByTagName(tag);
	for(j=0; j < children.length; j++){
		if(tag == 'img'){
			renameIDName(children[j], prefix+str, prefix+newStr);
		}else if(tag == 'input'){
			renameIDName(children[j], prefix+str, prefix+newStr);
			if(children[j].id == 'time_entry__issue_id'){
				renameOnChange(children[j], str, newStr);
			}
						
		}else if(tag == 'a'){
			renameHref(children[j], prefix+str, prefix+newStr);
		}else if(tag == 'select'){
			renameOnChange(children[j], prefix+str, prefix+newStr);
		}
	}
}

function renameIDName(child, str, newStr){
	var id = child.id;	
	var rExp = new RegExp(str);	
	if(id.match(rExp)){
		
		child.id = id.replace( rExp, newStr);
		var name = child.name;
		child.name = name.replace( rExp, newStr);
	}
}

function renameHref(child, str, newStr){
	var href = child.href;
	var rExp = new RegExp(str);
	if(href.match(rExp)){
		child.href = href.replace(rExp, newStr);
	}
}

function renameOnChange(child, index, newIndex){

	var row = newIndex;
	var onchng = child.onchange;
	var func = null;
	var enterIsueIdChk = document.getElementById("enter_issue_id");
	if(child.id == 'time_entry__project_id'){
		func = function(){projectChanged(this, row);};
	}else if(child.id == 'time_entry__issue_id'){
		if(enterIsueIdChk && enterIsueIdChk.checked){
			func = function(){issueAutocomplete(this, row);};
		}
	}
		
	if(func){
		//bind the row variable in the function
		//func.bind(this, row);
		//bind is not working well with IE after droping prototype
		if(enterIsueIdChk && enterIsueIdChk.checked)
		{
			child.onkeypress = func;
		}
		else
		{
			child.onchange = func;
		}
		
	}
}

function validateTotal(hourField, day, maxHour){
	var dayTotal = calculateTotal(day);
	var val = hourField.value;
	if(isNaN(maxHour))
	{
		maxHour=maxHour.replace(',', '\.');
	}
	maxHour= Number(maxHour);
	if (maxHour > 0 && dayTotal > maxHour){
		//val = val.replace(decSeparator, '\.');
		//#val = Number(val);
		val = validateHours(val, hourField)
		val = val - (dayTotal - maxHour);
		/*if(val == 0)
		{
			hourField.value = "";
		}
		else
		{*/
			hourField.value = val.toFixed(2);
		/*}*/
		dayTotal = maxHour;
	}
	updateDayTotal(day, dayTotal);
	if(showWorkHeader){
		updateRemainingHr(day);
	}
}

function calculateTotal(day){
	var issueTable = document.getElementById("issueTable");
	var totalSpan = document.getElementById("total_hours");
	var tab = document.getElementById("tab");
	var rowCount = issueTable.rows.length;
	var dayTotal = 0.0;
	var hours, i, j, k, val, children;
	
	//since it has a header,start,end,totalhr and total row use <  rowCount-2 and i=4
	for(i=headerRows; i < rowCount-footerRows; i++){
		//There is a bug in IE7, the getElementsByName doesn't get the new elements
		//hours = document.getElementsByName("hours" + i + "[]");			
		hours = myGetElementsByName(issueTable.rows[i], "input","hours" + (i - (headerRows - 1)) + "[]");
			
		val = myTrim(hours[day-1].value);
		//replace any . with . for internationalization
		if (tab.value =="wkexpense")
		{
			val = val.replace(decSeparator, '\.');
			if(isNaN(val)) //if(val == 0 || isNaN(val))
			{
				hours[day-1].value = "";
			}
			
			if( val != '' && !isNaN(val)){
				dayTotal += Number(val);
			} 
		}else{
		dayTotal += validateHours(val,hours[day-1])
		}
	}
	return dayTotal;
}

function validateHours(hoursValue,hoursDay){
	var valid =false
	hoursValue = myTrim(hoursValue);			
	var indexStr='',indexNextStr='',contcatStr='';					
	var hours ='',mins='',timeValue='',concatvalue ='';
	var total=0;
	if (!isNaN(hoursValue))	{
		hours = hoursValue;		
	}else if (hoursValue.indexOf('.') > -1){
		valid = checkStr(hoursValue,'.')				
	}else if (hoursValue.indexOf(",") > -1){
		valid = checkStr(hoursValue,",")
		if(!valid){				
			hours = hoursValue.replace(",", ".");
		}
	}else if (hoursValue.indexOf(":") > -1){
		valid = checkStr(hoursValue,":")
		if(!valid){
			var val = hoursValue.split(":");
			hours= val[0];
			mins = val[1];
		}
	}else{
		for (i = 0; i < hoursValue.length-1; i++){ 
			indexStr = hoursValue[i];
			indexNextStr = hoursValue[i+1]									
			if (!myTrim(indexNextStr) && indexStr && !contcatStr){									
				if (isNaN(indexStr)){
					valid = true
					break;
				}else{
					timeValue += indexStr;
				}
			}else{
				if (!isNaN(indexStr)){
					timeValue += indexStr;
				}if (isNaN(indexNextStr)){
					contcatStr += indexNextStr;							
				}else if (indexNextStr){							
					if (contcatStr =="h" || contcatStr =="hour" || contcatStr =="hours" ){
						contcatStr ='';
						hours = timeValue
						timeValue=''
						concatvalue=''
					}else if (contcatStr =="m" || contcatStr =="min"){
						contcatStr ='';
						mins = timeValue
						timeValue=''
						concatvalue=''
					}
					 concatvalue +=indexNextStr;
				}
			}					
		}
	}
	if (contcatStr =="h" || contcatStr =="hour" || contcatStr =="hours" ){
		contcatStr ='';
		hours = timeValue
		timeValue= ''
		concatvalue=''
	}else if (contcatStr =="m" || contcatStr =="min"){
		mins = timeValue
		timeValue=''
		concatvalue=''
	}else if (contcatStr){
		valid = true				
	}
	if (!myTrim(mins)){
		mins = concatvalue				
	}
	if (hours && mins){
		if(parseInt(mins) >60){
			valid = true;
		}
	}
	if (valid){
		hoursDay.value='';
	}else{
		 total = totalHours(hours,mins)				
	}
	return total;
}
function checkStr(hoursValue,type){
	var valid =true;			
	hoursValue = hoursValue.replace(type, ".");
	if (!isNaN(hoursValue))	{
		valid = false
	}
	return valid
}
function totalHours(hours,mins){		
	var minhour =0,total=0;
	if (!isNaN(hours) && myTrim(hours))
	{			
		total = parseFloat(hours)
	}
	if (!isNaN(mins) && myTrim(mins))
	{
		minhour = parseFloat(mins)/60;
		total +=parseFloat(minhour)
	}			
	return total
}

//There is a bug in IE7, the getElementsByName doesn't get the new elements
//Workaround for the getElementsByName bug found in IE7
function myGetElementsByName(parent, tag, name){
	
	var children = parent.getElementsByTagName(tag);	
	var mChildren = new Array();
	var j, k=0;
	for(j=0; j < children.length; j++){
		if(children[j].name == name){
			
			mChildren[k++] = children[j];
		}
	}
	return mChildren;
}

function myTrim(val){
	//IE doesn't support trim()
	return val.replace(/^\s\s*/, '').replace(/\s\s*$/, '');
}

function updateDayTotal(day, dayTotal){
	var day_total = document.getElementById('day_total_'+day);
	var currDayTotal = Number(day_total.innerHTML);
	day_total.innerHTML = dayTotal.toFixed(2);	
	updateTotal(dayTotal - currDayTotal);
}

function updateTotal(increment){
	var totalSpan = document.getElementById("total_hours");
	var totalHf = document.getElementById("total");
	var total = Number(totalSpan.innerHTML);
	total += increment;
	totalHf.value = total;
	totalSpan.innerHTML = total.toFixed(2);
}

function updateRemainingHr(day)
{
	var issueTable = document.getElementById("issueTable");
	var rowCount = issueTable.rows.length;
	var totalRow = issueTable.rows[rowCount-2];
	var rmTimeRow = issueTable.rows[rowCount-1];
	var totTime,cell,rmTimeCell,dayTt,remainingTm = 0;
	
	totTime = getTotalTime(day);
	
	//cell = totalRow.cells[hStartIndex + day];
	var day_total = document.getElementById('day_total_'+day);
	dayTt = Number(day_total.innerHTML);	
	rmTimeCell = rmTimeRow.cells[hStartIndex + day];
	if(totTime >  0)
	{
		remainingTm = totTime - dayTt;
	}		
	rmTimeCell.innerHTML = remainingTm.toFixed(2);
}

function getTotalTime(day)
{
	var s = 0;
	var minDiff = getMinDiff(day,s);			
	//totTime = Math.round((minDiff/60)*100)/100;	
	totTime = minDiff/60;
	return totTime;
}

//Returns the minutes difference between start and end time
function getMinDiff(day,s)
{
	var totTime,currDayTotal;
	var st_min,end_min,minDiff,minadd;
	var start, end;
	if(s == 0)
	{
		st_min = getMinutes(day,'start_');
		end_min = getMinutes(day,'end_');		
	}
	else if(s == 2 )
	{
		st_min = getMinutes(day,'newstart_');
		end_min = getMinutes(day,'newend_');		
	}
	else
	{
		st_min = getMinutes(day,'popupstart_');
		end_min = getMinutes(day,'popupend_');
		start = document.getElementById("popupstart_" + day).value ;
		end = document.getElementById("popupend_" + day).value  ;
	}
	
	if(st_min > end_min)
	{
		if(st_min <= 720)
		{
			end_min += 720;
		}
		else
		{
			end_min += 1440;
		}
	}
	minDiff = end_min - st_min;	
	return minDiff;
}

//convert the hour to minutes 
function getMinutes(day,str)
{
	var fldVal,fldVal_min;
	fldVal =  document.getElementById(str+day).value;	
	/*if(!fldVal)
	{
		fldVal = "00:00";
	}*/	
	fldVal = fldVal.split(":");
	fldVal_min = (fldVal[0] * 60) + parseInt(fldVal[1]);	
	return fldVal_min;
}

//Calculates and fills the total hr
function updateTotalHr(day)
{	
	var issueTable = document.getElementById("issueTable");
	var totTimeRow = issueTable.rows[3];
	var tot_Hr = 0,tot_min = 0,totTime="";
	var s =0;
	var minDiff = getMinDiff(day,s);
	
	/*if(minDiff > 0)
	{	*/	
		tot_Hr = parseInt(minDiff/60) ;
		tot_min = minDiff%60;
		if (tot_min > 0)
		{ 
			totTime = tot_Hr + ":" + tot_min;
		}
		else
		{
			totTime = tot_Hr + ":00";
		};	
		//alert("update total hours " + totTime);
	//	timediff(day,totTime, "hoursstart_");
		//totHrCell = totTimeRow.cells[hStartIndex + day];
	//	totHrCell.innerHTML = totTime + "     <a href='javascript:showclkDialog("+day+");'><img id='imgid' src='../plugin_assets/redmine_wktime/images/clockin.png' border=0 title=''/></a>";
	/*}*/	
}
function showclkDialog(day)
{
	var i;
	for(i = 1; i < 8 ; i++)
	{
		if(day == i)
		{
			document.getElementById('img_'+ i).style.display = 'block';
			$( "#clockInOut-dlg" ).dialog( "open" );
		}
		else
		{
			document.getElementById('img_'+ i).style.display = 'none';
		}
		
	}
}

//Validates the start and end time
function validateHr(hrFld,day)
{		
	var hrFldID = hrFld.id;
	var hrVal = document.getElementById(hrFldID).value;	
	if(hrVal == "")
	{
		hrFld.value = "0:00";
		hrVal = "0:00";
	}
	
	
	if(hrVal.match(/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/) == null)
	{
		hrFld.value = "0:00";
		alert("Not a valid time format");
	}
	else
	{	
		updateRemainingHr(day);	
		updateTotalHr(day);
	}
}

function setClockInOut(strid,id) {
       var d = new Date();
	   var hh = d.getHours();
	   var mm = d.getMinutes();
	   id++;
	   //elementid = document.getElementById(strid + '_' + id);
	  // hh = hh % 12;   convert 24 hours to 12 hours
	   elementhour = hh + ":" + mm;
	   elementend = hh + ":" + mm;
	   if( strid == 'start')
	   {
		  document.getElementById('end_img' ).style.visibility = "visible";
		  document.getElementById('start_img').style.visibility = 'hidden';
	   }
	   else
	   {
		  document.getElementById('start_img' ).style.visibility = "visible";
		  document.getElementById('end_img').style.visibility = 'hidden';
	   }
	   
	   
	   //document.getElementById(strid + '_' + id).disabled  = true;)
	   updateClockInOut(elementhour, strid, id, elementend );
	   //elementid.onclick=function(){updateClockInOut(this.value, strid, id)};
}

function updateClockInOut(entrytime, strid, id, elementend){
	var $this = $(this);		
	var hours,start,end, hoursdiff;
	elementid = document.getElementById('hd'+strid + '_' + id).value;
	if(strid == "end")
	{
		start = document.getElementById('start_' + id).value;
		end = elementend //document.getElementById('end_' + id).value;
		hoursdiff = diff(start, end);
		timediff(id,hoursdiff, 'hoursstart_');
		hours = document.getElementById('hoursstart_' + id).value;
	}	
	//hoursClockInOut(0,id)
	
	var params = strid == 'start' ? {starttime: entrytime} 	: {endtime :entrytime, id: elementid, differences: hours };
	$.ajax({
		url: 'saveAttendance',
		type: 'get',
		data: params,
		success: function(data){ hiddenClockInOut(data, strid, id); },  
		complete: function(){ $this.removeClass('ajax-loading'); }
	});		
}

function hiddenClockInOut(data,strid,id){
	var array = data.split(',');
	hdstart = document.getElementById('hdstart_' + id);
	hdstart.value = array[0];
	
	hdend = document.getElementById('hdend_' + id);
	hdend.value = array[0];
	
	elementid = document.getElementById(strid + '_' + id);
	elementid.value = strid == 'start' ? array[1] : array[2];
	updateRemainingHr(id);	
	updateTotalHr(id); //old place
	
}

function hoursClockInOut(s,id)
{
	
	var startvalue,endvalue;
	var tot_Hr = 0,tot_min = 0,totTime="";
	var minDiff = getMinDiff(id,s);
	
		tot_Hr = parseInt(minDiff/60) ;
		tot_Hr = isNaN(tot_Hr) ? 0 : tot_Hr;
		tot_min = minDiff%60;
		if (tot_min > 0)
		{ 
			totTime = tot_Hr + ":" + tot_min;
		}
		else
		{
			totTime = tot_Hr + ":00";
		};	
		
		if(s == 1)
		{
			timediff(id,totTime, "total_");
			
		}
		else if( s == 0)
		{
			alert("totime" + totTime);
			timediff(id,totTime, 'hoursstart_');
		}
		else
		{
			//document.getElementById('newdiff_' + id).value = totTime;
			timediff(id,totTime, 'newdiff_');
		}
			
}

function timediff(id, totTime, str)
{
	var start,end, startBT,endBT;
	var breakTime = new Array();
	var breakValue = new Array();	
	var count = 0, count1 = 0, count2 = 0  ;
	var i =0, j = 0;
	var minusdiff;
	var oldtotal = "00:00:00" ;
	if(str == "total_")
	{
	start = document.getElementById("popupstart_" + id).value ;
	end = document.getElementById("popupend_" + id).value  ;
	}
	else if(str == "newdiff_")
	{
		start = document.getElementById("newstart_" + id).value ;
		end = document.getElementById("newend_" + id).value  ;
	}
	else{
		start = document.getElementById("start_" + id).value ;
		end = document.getElementById("end_" + id).value  ;
		alert(" start : " + start + " end : " + end);
	}
	if(start && end)
	{					
		breakTime = document.getElementById('break_time').value;
		breakTime = breakTime.split(" ");	
		var startBTime = new Array() ,endBTime = new Array();
		for(i= 0; i < breakTime.length ; i++)
		{				
			breakValue =  breakTime[i].split('|');
			startBTime[i]= breakValue[0] + ":" + breakValue[1] + ":00" ;
			endBTime[i] = breakValue[2] + ":" + breakValue[3] + ":00";						
		}
		var diffbetween,diffbetween1, diffbetween4,diffbetween5;
		var dbtotal , stdiff;				
		start += ":00";
		end += ":00";
		for(j=0;j < startBTime.length ; j++)
		{					
			startBT = dateCompare(start,startBTime[j],0);
			endBT = dateCompare(end,endBTime[j],0);
			// calculate time from greater & less then break time and inbetween clock in/out
			if((startBT == -1 && endBT == 1  ) || ( startBT == 0 && endBT == 0) || (startBT == 1 && endBT == -1  ) || 
			(startBT == -1 && endBT == 0) || (startBT == 0 && endBT == 1) )  //|| (st1 == -1 && ed1 == -1  ) st ed
			{
				var oldval = stdiff;
				stdiff  = diff(startBTime[j],endBTime[j]);
				if(count == 1)
				{
					stdiff = MinutesDifferent(oldval,stdiff,1);
				}
				count = 1;						
				minusdiff = MinutesDifferent(totTime,stdiff,0);						
				if (startBT == 1 && endBT == -1 ) 
				{
					minusdiff = "0:00";
				}						
				document.getElementById(str + id).value =  minusdiff;
			}
			else
			{
				if(count != 1)
				{
					//break time greater then clock out time
					
					diffbetween = dateCompare(end,endBTime[j],1);
					diffbetween1 = dateCompare(startBTime[j],end,1);
					if(diffbetween == 2 && diffbetween1 == 2)
					{
						count1 = 1;
						dbtotal = MinutesDifferent(startBTime[j],start, 0 );
						document.getElementById(str + id).value =  dbtotal;
					}
					else{
						if(count1 != 1 )
						{
							//break time less then clock in time							
							diffbetween4 = dateCompare(start,startBTime[j],2);
							diffbetween5 = dateCompare(start,endBTime[j],2);
							if(diffbetween4 == 4 && diffbetween5 == 0)
							{
								count2 = 1;
								dbtotal = MinutesDifferent(end, endBTime[j], 0 );
								document.getElementById(str + id).value =  dbtotal;
							}
							else
							{								
								if(count2 != 1)
								{
									// 12 hours format to calculate all break time
									/*	var twlevetotal = dateCompare(start,end, 3);
										if(twlevetotal == 6)
										{
											if(diffbetween4 == 0 && diffbetween5 == 0)
											{
												var ttotal = MinutesDifferent(  endBTime[j], startBTime[j], 0 );
												//alert("oldtt 1c " + oldtotal + " ttotal : " + ttotal);
												oldtotal = MinutesDifferent( ttotal, oldtotal, 1 );
												var overalltotal = MinutesDifferent(totTime, oldtotal, 0 );
											}
											document.getElementById('total_' + id).value = overalltotal;
										}	*/								
									//else{
										document.getElementById(str + id).value = totTime;
									//}
									
								}
								
								
							
							}
							
							
						}
					}
					
				}
				
			}				
		}				
	}		
}

function MinutesDifferent(totTime, stdiff, variation)
{
	var minusdiff;
	var seconds,seconds1;	
	var arr,arr1;
	arr = totTime.split(':');	
	arr1 = stdiff.split(':');
	seconds = arr[0]*3600+arr[1]*60;
	seconds1 = arr1[0]*3600+arr1[1]*60;
	
	if(variation == 1)
	{
		minusdiff = seconds + seconds1;
	}
	else{
		minusdiff = seconds - seconds1;
	}	 
	var d;
	d = Number(minusdiff);
	var h = Math.floor(d / 3600);
	var m = Math.floor(d % 3600 / 60);
	minusdiff =  ((h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + (h > 0 ? m : ("0:" + m)) );
	//alert(" minusdiff 12312  : " + minusdiff);
	return minusdiff;
}

function dateCompare(time1,time2,s) {
  var t1 = new Date();
  var parts = time1.split(":");
  t1.setHours(parts[0],parts[1],parts[2],0);
  var t2 = new Date();
  parts = time2.split(":");
  t2.setHours(parts[0],parts[1],parts[2],0);  
  // returns 1 if greater, -1 if less and 0 if the same  
  if(s == 1)
  {
	if (t1.getTime()<t2.getTime()) return 2;
	if (t1.getTime()<t2.getTime()) return 3;  
  }
  else if (s == 2)
  {
	  if (t1.getTime() > t2.getTime()) return 4;
	  if (t1.getTime() > t2.getTime()) return 5;
  }
  else if (s == 3)
  {
	  if (t1.getTime() > t2.getTime()) return 6;
	  
  }
  else
  {
	  if (t1.getTime()>t2.getTime()) return 1;
      if (t1.getTime()<t2.getTime()) return -1;
  }
  return 0;
}

function diff(start, end) {
    start = start.split(":");
    end = end.split(":");
    var startDate = new Date(0, 0, 0, start[0], start[1], 0);
    var endDate = new Date(0, 0, 0, end[0], end[1], 0);
    var diff = endDate.getTime() - startDate.getTime();
    var hours = Math.floor(diff / 1000 / 60 / 60);
    diff -= hours * 1000 * 60 * 60;
    var minutes = Math.floor(diff / 1000 / 60);
    
    return (hours < 9 ? "0" : "") + hours + ":" + (minutes < 9 ? "0" : "") + minutes;
}

function totalClockInOut()
{
	//when initially load the page update the dialog box  grand total
	var splitid;
	var totalsplitvalues;
	var grandtotal = document.getElementById('grandtotal').value;
	totalsplitvalues = grandtotal.split('|');
	var addval = new Array();
	var start,ch;
	var adding = 0;
	var seconds;
	for(i=0; i < totalsplitvalues.length ; i++)
	{		
		  for(j=0;j< totalsplitvalues[i].length && totalsplitvalues[i].length > 1; j++)
		  {
			  splitid = totalsplitvalues[i].split(',');
			  var inval, outval;			 
			  if(splitid[j])
			  { 
				  
				 inval = document.getElementById('total_' + splitid[j]).value;
				 start = inval.split(':');				 
				 seconds = start[0]*3600+start[1]*60
				 adding += seconds; 				
			  }
		  }
		  if(ch != i )
			{
				addval[i] =  adding;
				adding = 0;
			}				 
		  ch = i;			  
		  if(addval[i])
		  {			 
			var d;
			d = Number(addval[i]);
			var h = Math.floor(d / 3600);
			var m = Math.floor(d % 3600 / 60);
			addval[i] =  ((h > 0 ? h + ":" + (m < 10 ? "0" : "") : "") + (h > 0 ? m : ("0:" + m)) );		    	  
			document.getElementById('grandTotal_' + (i) ).value = addval[i];			
		  }	 		  
	}
	for( i =1; i < 8 ; i++)
	{
		var issueTable = document.getElementById("issueTable");
		var totTimeRow = issueTable.rows[3];		 
		totHrCell = totTimeRow.cells[hStartIndex + (i+1) ];	
		addval[i] = addval[i] ? addval[i] : "00:00"	
		totHrCell.innerHTML = addval[i] + "     <a href='javascript:showclkDialog("+i+");'><img id='imgid' src='../plugin_assets/redmine_wktime/images/clockin.png' border=0 title=''/></a>";
		 
	}
}

function issueAutocomplete(txtissue,row){    
        var uid = document.getElementById("user_id").value;
		var startday = document.getElementById("startday").value;
		var issUrl = document.getElementById("getissues_url").value;
		issue_assign_user=issueAssignUser();
       	issUrl= issUrl + "?user_id=" + uid + "&issue_assign_user=" + issue_assign_user + "&startday=" + startday;
        $(txtissue).autocomplete({                    
			source: issUrl ,
			minLength:2,
			select: function(event,ui){
				issueIdChanged(ui.item.value, row);
			}
        });
}

function validateMinhour(minHour,nonWorkingDay){
	var valid=true;
	var totalhr = document.getElementById("total_hours").innerHTML;
	totalhr = Number(totalhr);
	 minHour=minHour.replace(decSeparator, '\.');
	 if(isNaN(minHour)){
		minHour=minHour.replace(',', '\.');
	 }
	 
	 if (minHour!=0 && !isNaN(minHour)){	
		 for (i=1;i<=7;i++){
			var dayTotal= document.getElementById('day_total_'+i).innerHTML;
			dayTotal = Number(dayTotal.replace(decSeparator, '\.'));
			if(nonWorkingDay.indexOf(i.toString())== -1 || dayTotal > 0){				
				
				if (dayTotal< Number(minHour)){
					alert(minHourAlertMsg);
					valid=false
					break;
				}
			}
		 }
	 }
	 
	if(valid  && submissionack!=''){
		valid= confirm(submissionack);
	}
	return valid;
}

function issueAssignUser()
{
	var issueAssignUser = document.getElementById('issue_assign_user');
	var issue_assign_user=0;
	if(issueAssignUser && issueAssignUser.checked)
	{
		issue_assign_user=1;
	}
	return issue_assign_user
}

function getDefaultActId(actStr)
{
	var index, actId = null;
	index = actStr.indexOf('|true|', 0);
	if(index != -1){
		actStr = actStr.substring(0,index);
		index = actStr.lastIndexOf('|');
		actId = actStr.substring(index+1);
	}
	return actId
}
