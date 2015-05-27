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
var hStartIndex = 6;
var issueField = 'Issue';
var submissionack="";
var minHourAlertMsg="";
var decSeparator = ".";
$(document).ready(function() {
//$(function() {
	var e_comments = $( "#_edit_comments_" );
	var e_notes = $( "#_edit_notes_" );

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
						$(x[comment_col-1]).attr({src: "/plugin_assets/redmine_wktime/images/withcommant.png"});
						
					}
					else
					{					
						$(x[comment_col-1]).attr({src: "/plugin_assets/redmine_wktime/images/withoutcommant.png"});
					}					
					$( this ).dialog( "close" );				
					//unregister this event since this is showing a 'don't leave' message
					//loosk like this is not supported in Opera
					window.onbeforeunload = null;
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

	
});

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
			issDropdowns[i].options[issDropdowns[i].selectedIndex].text : '');
	}
	$( "#_edit_comm_act_" ).html(actDropdowns[i].selectedIndex >= 0 ?
		actDropdowns[i].options[actDropdowns[i].selectedIndex].text : '');
	
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
			success: function(data){ updateDropdown(data, row, issDropdown, true, allowBlankIssue, true,null); },
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading'); }
		});
		$.ajax({
			url: actUrl,
			type: 'get',
			data: {project_id: id, user_id: uid, format:fmt},
			success: function(data){ updateDropdown(data, row, actDropdown, false, false, true,null); },
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
	if(projDropdowns){	
		for (j=0; j < projDropdowns.length; j++){		
			proj_id = projDropdowns[j].options[projDropdowns[j].selectedIndex].value;
			if(proj_id != '' && project_id == proj_id){			
				if(issDropdowns[j]){									
					if(issDropdowns[j].value != ""){						
						issue_id = issDropdowns[j].options[issDropdowns[j].selectedIndex].value;
					}	
					else{
						issue_id=null;
					}
					updateDropdown(itemStr, j+1, issDropdowns, true, allowBlankIssue, true, issue_id);					
				}
			}
		}
	}
}
function updateActDropdown(data, row, actDropdown){
	
	var enterIsueIdChk = document.getElementById("enter_issue_id");
	if(enterIsueIdChk && enterIsueIdChk.checked){
		//set the project id
		var projectIdHFs = document.getElementsByName("time_entry[][project_id]");
		var items = data.split('\n');
		var index;
		if(items.length > 0){
			index = items[0].indexOf('|');
			if(index != -1){
				//set the project id
				projectIdHFs[row-1].value = items[0].substring(0, index);
			}
		}
	}
	updateDropdown(data, row, actDropdown, false, false, true,null);
}

function updateDropdown(itemStr, row, dropdown, showId, needBlankOption, skipFirst, selectedVal)
{
	var items = itemStr.split('\n');
	var selectedValSet = false;	
	dropdown[row-1].options.length = 0;
	if(needBlankOption){
		dropdown[row-1].options[0] = new Option( "", "", false, false); 
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
			if(showId)
			{
				text = text.split('|');
			}
			dropdown[row-1].options[needBlankOption ? i+1 : i] = new Option( 
				showId ? text[0] + ' #' + val + ': ' + text[1] : text, val, false, val == selectedVal);			
			if(val == selectedVal){
				selectedValSet = true;
			}
		}
	}
	if(selectedVal && !selectedValSet){
		dropdown[row-1].options[needBlankOption ? i+1 : i] = new Option( 
				selectedVal, selectedVal, false, true);
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
	hoursValue = hoursValue.trim();			
	var indexStr='',indexNextStr='',contcatStr='';					
	var hours ='',mins='',timeValue='',concatvalue ='';
	var total=0;
	if (!isNaN(hoursValue))	{
		hours = hoursValue;		
	}else if (hoursValue.indexOf('.') ==1){
		valid = checkStr(hoursValue,'.')				
	}else if (hoursValue.indexOf(",")==1){
		valid = checkStr(hoursValue,",")
		if(!valid){				
			hours = hoursValue.replace(",", ".");
		}
	}else if (hoursValue.indexOf(":")==1){
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
			if (!indexNextStr.trim() && indexStr && !contcatStr){									
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
	if (!mins.trim()){
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
	if (!isNaN(hours) && hours.trim())
	{			
		total = parseFloat(hours)
	}
	if (!isNaN(mins) && mins.trim())
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
	var minDiff = getMinDiff(day);			
	//totTime = Math.round((minDiff/60)*100)/100;	
	totTime = minDiff/60;
	return totTime;
}

//Returns the minutes difference between start and end time
function getMinDiff(day)
{
	var totTime,currDayTotal;
	var st_min,end_min,minDiff;
	st_min = getMinutes(day,'start_');
	end_min = getMinutes(day,'end_');
	
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
	var minDiff = getMinDiff(day);
	
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
		
		totHrCell = totTimeRow.cells[hStartIndex + day];		
		totHrCell.innerHTML = totTime;
	/*}*/
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
		alert("Not a valid time format");
	}
	else
	{	
		updateRemainingHr(day);	
		updateTotalHr(day);
	}
}

function issueAutocomplete(txtissue,row){    
        var uid = document.getElementById("user_id").value;
		var issUrl = document.getElementById("getissues_url").value;
		issue_assign_user=issueAssignUser();
       	issUrl= issUrl +"?user_id="+ uid +"&issue_assign_user=" +issue_assign_user;
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
