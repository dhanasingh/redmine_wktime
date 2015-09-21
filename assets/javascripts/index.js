var wktimeIndexUrl,wkexpIndexUrl;
var no_user ="";
var grpUrl="";
var userUrl="";
var userList = new Array();
var rSubEmailUrl = "";
var rAppEmailUrl = "";

$(document).ready(function() {
	$( "#reminder-email-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: true,
		buttons: {
			"Ok": function() {				
				var email_notes = document.getElementById('email_notes').value;
				//alert("email_notes : " + email_notes);
				var commandEl = document.getElementsByName('submission');
				var reminder_command = 0;
				for(var i = 0; i < commandEl.length; i++) {
					if(commandEl[i].checked) {
						reminder_command = commandEl[i].value;
					}
				}
				var rUrl = "";
				if (reminder_command == 1) {
					rUrl = rSubEmailUrl;
				} else {
					rUrl = rAppEmailUrl;
				}
				//alert("reminder_command : " + reminder_command + ", rUrl : " + rUrl);
				var from = document.getElementById('from').value;
				var to = document.getElementById('to').value;
				//var selectedValue = document.getElementById('user_id').value;
				var userOpt = document.getElementById('user_id').options;
				var strUserIds = "";
				var arrUserId = []
				for(var i = 1; i < userOpt.length; i++) {
				    //0 -- All User
					arrUserId.push(userOpt[i].value);
				}
				strUserIds = arrUserId.toString();
				
				$.ajax({
					url: rUrl,
					type: 'get',
					//data: {user_ids: strUserIds, status: strStatus, from: from, to: to, email_notes: email_notes},
					data: {user_ids: strUserIds, from: from, to: to, email_notes: email_notes},
					success: function(data){ 
						//alert("Email sent successfully")
						document.getElementById('email_notes').value = "";
						document.getElementsByName('submission')[0].checked = true;
						$('textarea').removeData('changed');
					}//,
					//beforeSend: function(){ $(this).parent().addClass('ajax-loading'); },
					//complete: function(){ $(this).parent().removeClass('ajax-loading'); }
				});
				$( this ).dialog( "close" );
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});
});

function showReminderEmailDlg() {
	$( "#reminder-email-dlg" ).dialog( "open" );
	//return false so the form is not posted
	//return false;
}

function projChanged(projDropdown, userid, needBlankOption){
	
	var id = projDropdown.options[projDropdown.selectedIndex].value;
	var fmt = 'text';
	var userDropdown = document.getElementById("user_id");
	var $this = $(this);
	
	$.ajax({
		url: userUrl,
		type: 'get',
		data: {project_id: id, user_id: userid, format:fmt},
		success: function(data){ updateUserDD(data, userDropdown, userid, needBlankOption, false); },
		beforeSend: function(){ $this.addClass('ajax-loading'); },
		complete: function(){ $this.removeClass('ajax-loading'); }
	});
	
}

function updateUserDD(itemStr, dropdown, userid, needBlankOption, skipFirst)
{
	
	var items = itemStr.split('\n');
	var i, index, val, text, start;
	dropdown.options.length = 0;
	if(needBlankOption){
		dropdown.options[0] = new Option("All Users", "0", false, false) 
	}
	for(i=0; i < items.length-1; i++){
		index = items[i].indexOf(',');
		if(skipFirst){
			if(index != -1){
				start = index+1;
				index = items[i].indexOf(',', index+1);
			}
		}else{
			start = 0;
		}
		if(index != -1){
			val = items[i].substring(start, index);
			text = items[i].substring(index+1);
			dropdown.options[needBlankOption ? i+1 : i] = new Option( 
				text, val, false, val == userid);
		}
	}
}


$(document).ready(function()
{
	changeProp('tab-wktime',wktimeIndexUrl);
	changeProp('tab-wkexpense',wkexpIndexUrl);
});


function changeProp(tab,indexUrl)
{
	var tab_te = document.getElementById(tab);
	var tabName = tab.split('-');
	if(tab_te != null)
	{
		tab_te.href = indexUrl;
		tab_te.onclick = function(){
			var load = false;
			if(prevTab != (this.id).toString())
			{
				load = true;
			}			
			prevTab = this.id;
			return load;
		};
	}
}

function validateMember()
{
	var valid=true;
	var userDropdown = document.getElementById("user_id");
	if (userDropdown.value=="")
	{
		valid=false;
		alert(no_user);
	}
	return valid;
}

function grpChanged(grpDropdown, userid, needBlankOption){
	
	var id = grpDropdown.options[grpDropdown.selectedIndex].value;
	var fmt = 'text';
	var userDropdown = document.getElementById("user_id");
	var $this = $(this);
	$.ajax({
		url: grpUrl,
		type: 'get',
		data: {user_id: userid, format:fmt,group_id:id},
		success: function(data){ updateUserDD(data, userDropdown, userid, needBlankOption, false); },
		beforeSend: function(){ $this.addClass('ajax-loading'); },
		complete: function(){ $this.removeClass('ajax-loading'); }
	});
}
function progrpChanged(btnoption, userid, needBlankOption){
	if (btnoption.value==1){
		projChanged(document.getElementById("project_id"), userid, needBlankOption)
	}
	else{
		grpChanged(document.getElementById("group_id"), userid, needBlankOption)
	}
}