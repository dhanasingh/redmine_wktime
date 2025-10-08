var wktimeIndexUrl, wkexpIndexUrl, wkattnIndexUrl,wkReportUrl,clockInOutUrl, payrollUrl, blgaccUrl, blgcontractsUrl, blgaccpjtsUrl,
	blginvoiceUrl, blgtaxUrl, blgtxnUrl, blgledgerUrl, crmdashboardUrl, crmleadsUrl, crmopportunityUrl, crmactivityUrl, crmcontactUrl, crmenumUrl,
	blgpaymentUrl, blgexcrateUrl, purRfqUrl, purQuoteUrl, purPurOrderUrl, purSupInvUrl, purSupAccUrl, purSupContactUrl, purSupPayUrl,
	wklocationUrl,  wkproductUrl, wkproductitemUrl, wkshipmentUrl, wkassetUrl, wkassetdepreciationUrl, wkgrpPermissionUrl, wkSchedulingUrl,
	userCurrentUrl, wkSurveyUrl, wkleavereqUrl, wknotificationUrl, wkskillUrl, wkreferralsUrl, wkdeliveryUrl, salesquoteUrl, wkuserUrl;
var no_user ="";
var grpUrl="";
var userUrl="";
var accountUrl ="";
var userList = new Array();
var rSubEmailUrl = "";
var rAppEmailUrl = "";

//For Colorcode in Sidebar-white theme
var colorcode_statuses = {
  Empty: 1,
  New: 0,
  Rejected: 2,
  Submitted: 4,
  Approved: 3,
  Cancelled: 1,
  Assigned: 4,
  In_Process: 5,
  Converted: 3,
  Recycled: 1,
  Dead: 2,
  Planned: 0,
  Not_Held: 2,
  Held: 3,
  Open: 6,
  Closed: 1,
  Contra: 0,
  Payment: 1,
  Receipt: 2,
  Journal: 3,
  Sales: 4,
  Credit_Note: 5,
  Purchase: 6,
  Debit_Note: 7,
  Fulfilled: 4,
  Delivered: 3,
  Archived: 2,
  In_Transit: 5,
  Loading: 4
};

$(document).ready(function() {
	$( "#reminder-email-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: true,
		width: 380,
		buttons: [
			{
				text: 'Ok',
				id: 'btnOk',
				click: function() {
					var email_notes = document.getElementById('email_notes').value;
					var commandEl = document.getElementsByName('reminder');
					var reminder_command = 0;
					for(var i = 0; i < commandEl.length; i++) {
						if(commandEl[i].checked) {
							reminder_command = commandEl[i].value;
						}
					}
					var rUrl = "";
					if(reminder_command == 1) {
						rUrl = rSubEmailUrl;
					}
					else if(reminder_command == 2) {
						rUrl = rAppEmailUrl;
					}
					var from = document.getElementById('from').value;
					var to = document.getElementById('to').value;
					if(rUrl != "") {
						$.ajax({
							url: rUrl,
							type: 'post',
							data: {/*user_ids: strUserIds,*/ from: from, to: to, /*status: strStatus, */email_notes: email_notes},
							success: function(data){
								resetReminderEmailDlg();
								if(data != "OK") {
									alert(data);
								}
							},
							error: function(xhr,status,error) {
								resetReminderEmailDlg();
							},
							beforeSend: function(){ $(this).parent().addClass('ajax-loading'); },
							complete: function(){ $(this).parent().removeClass('ajax-loading'); }
						});
					}
					$( this ).dialog( "close" );
				}
			},
			{
				text: 'Cancel',
				id: 'btnCancel',
				click: function() {
					$( this ).dialog( "close" );
					resetReminderEmailDlg();
				}
			}
		]
	});

	//Hide summaryDD in Trasaction
	$("#txn_ledger").change(function() {
		hideSummaryDD(this.value);
	});
	hideSummaryDD($("#txn_ledger").val());

	//Set Overheadcost in transfer item
	if($('#transfer_item_id').length > 0){
		setOverHeadCost();
		$('#available_quantity').change(function(){
			setOverHeadCost();
		  });
	}

	$('#productItem #available_quantity').change(function(){
		$("#item_total_quantity").html(this.value);
		$('#total_quantity').val(this.value);
	});

	//populate invoice items for delivery
	if($('#delivery_invoice_id').val() == '') $('#populate_items').hide();
	$('#delivery_invoice_id').change(function(){
		if(this.value != ""){
			$("#populate_items").show();
		}
		else{
			$("#populate_items").hide();
		}
	});

	changeProp('tab-wktime',wktimeIndexUrl);
	changeProp('tab-wkexpense',wkexpIndexUrl);
	changeProp('tab-leave',wkattnIndexUrl);
	changeProp('tab-clock',clockInOutUrl);
	changeProp('tab-payroll',payrollUrl);
	changeProp('tab-wkcrmaccount',blgaccUrl);
	changeProp('tab-wkcontract',blgcontractsUrl);
	changeProp('tab-wkaccountproject',blgaccpjtsUrl);
	changeProp('tab-wkinvoice',blginvoiceUrl);
	changeProp('tab-wktax',blgtaxUrl);
	changeProp('tab-wkgltransaction',blgtxnUrl);
	changeProp('tab-wkledger',blgledgerUrl);
	changeProp('tab-wkcrmdashboard',crmdashboardUrl);
	changeProp('tab-wklead',crmleadsUrl);
	changeProp('tab-wkopportunity',crmopportunityUrl);
	changeProp('tab-wkcrmactivity',crmactivityUrl);
	changeProp('tab-wkcrmcontact',crmcontactUrl);
	changeProp('tab-wkcrmenumeration',crmenumUrl);
	changeProp('tab-wkpayment',blgpaymentUrl);
	changeProp('tab-wkexchangerate',blgexcrateUrl);
	changeProp('tab-wkrfq',purRfqUrl);
	changeProp('tab-wkquote',purQuoteUrl);
	changeProp('tab-wkpurchaseorder',purPurOrderUrl);
	changeProp('tab-wksupplierinvoice',purSupInvUrl);
	changeProp('tab-wksupplierpayment',purSupPayUrl);
	changeProp('tab-wksupplieraccount',purSupAccUrl);
	changeProp('tab-wksuppliercontact',purSupContactUrl);
	changeProp('tab-wklocation',wklocationUrl);
	changeProp('tab-wkproduct',wkproductUrl);
	changeProp('tab-wkproductitem',wkproductitemUrl);
	changeProp('tab-wkasset',wkassetUrl);
	changeProp('tab-wkassetdepreciation',wkassetdepreciationUrl);
	changeProp('tab-wkshipment',wkshipmentUrl);
	changeProp('tab-wkgrouppermission',wkgrpPermissionUrl);
	changeProp('tab-wkscheduling',wkSchedulingUrl);
	changeProp('tab-wksurvey',wkSurveyUrl);
	changeProp('tab-wkleaverequest',wkleavereqUrl);
	changeProp('tab-wknotification',wknotificationUrl);
	changeProp('tab-wkskill',wkskillUrl);
	changeProp('tab-wkreferrals',wkreferralsUrl);
	changeProp('tab-wkdelivery',wkdeliveryUrl);
	changeProp('tab-wksalesquote',salesquoteUrl);
	changeProp('tab-wkuser',wkuserUrl);

	showHidePartNumber();
	$('#automatic_product_item').change(function(){
		showHidePartNumber();
	});

	//accordion section
	$( "#accordion" ).accordion({
		icons: { "header": "accordion-icon-header", "activeHeader": "accordion-icon-header-active" },
		collapsible: true,
		heightStyle: "content"
	});

	// for searchable dopdown
	if($("select#referred_by").length > 0) $("#referred_by").select2();

	$("#assembleItem" ).dialog({
		modal: true,
		autoOpen: false,
		title: 'Assemble New Item',
		width: "50%",
		height: 370,
		buttons: {
			"Ok": function() {
				let rowlength = $('#assembleItemTable >tbody >tr').length;
				let item_id = $('#product_item').val();
				let quantity = $("#quantity").val();
				let item_avail_quantity = $("#item_avail_quantity").val();
				let tr = '', sn = [], index_no = (rowlength+1);
				if($('#serial_no').val()){
					($('#serial_no').val().split(',')).map(function(number){ sn.push({id:'', serial_number: number.trim()})});
				}
				if(!item_id){
					alert("Item cannot be blank");
				}
				else if(parseFloat(quantity) > parseFloat(item_avail_quantity)){
					alert('Quantity is higher than avilable quantity');
				}
				else{
					let item = {};
					item = {index_no: index_no, inventory_item_id: item_id, quantity: quantity, location_id: $('#location_id').val(), serial_no: sn}
					tr += '<tr>';
					tr += '<td class="lbl-txt-align">'+index_no+'</td>';
					tr += '<input type="hidden" name="assemble[item_'+index_no+']" id="assemble_item_'+index_no+'" value='+(JSON.stringify(item))+'></td>';
					tr += '<td class="lbl-txt-align">'+$('#product :selected').text()+'</td>';
					tr += '<td class="lbl-txt-align">'+$('#product_item :selected').text()+'</td>';
					tr += '<td class="lbl-txt-align">'+quantity+'</td>';
					tr += '<td class="lbl-txt-align">'+$('#location_id :selected').text();+'</td>';
					tr += '<td><a title="Delete" href="javascript:deleteItemRow('+ index_no +');">'+delImg+' </a> </td>';
					tr += '</tr>';
					$('#assembleItemTable > tbody:last-child').append(tr);
					$(this).dialog("close");
				}
			},
			"Cancel": function() {
				$(this).dialog("close");
			}
		}
	});

	$('#material_sn').change(function(){
		let sn =[];
		let product_serial_numbers = $('#product_serial_numbers').val();
		if($(this).val() != '' && (JSON.parse(product_serial_numbers).length) > 0){
			let material_sn = $(this).val().split(',');
			// show hide serialnumber note
			showHideSnNote($(this).val());

			let hidden_sn = $('#hidden_sns').val();
			let hidden_sn_arr = JSON.parse(hidden_sn);
			let sns =[];
			hidden_sn_arr.map(function (ele, i) { if(!ele['is_delete']) sns.push(ele['serial_number']) });
			let removed_sns = sns.filter(x => !material_sn.includes(x));
			if(removed_sns.length > 0){
				hidden_sn_arr.map(function (ele, i) { if(removed_sns.includes(ele['serial_number'])) ele['is_delete'] = true; });
			}
			let added_sns = material_sn.filter(x => !sns.includes(x));
			if(added_sns.length > 0){
				added_sns.map(function (number) { hidden_sn_arr.push({id: '', serial_number: number})});
			}
			$('#hidden_sns').val(JSON.stringify(hidden_sn_arr));
		}
	});

	$('.itemSN').change(function(){
		showHideSnNote($(this).val());
	});
	$('#inv_serial_no').change(function(){
		let fullSerNo = $("#item_serial_no").val();
		full_serno_ele = fullSerNo.split(',')
		let serialNumbers = getSerialNumbersRange(full_serno_ele[0], full_serno_ele[1], full_serno_ele[2]);
		showHideSnNote($(this).val(), JSON.stringify(serialNumbers));
	});
});

function showHideSnNote(consumed_sn, serialNumbers=[]){
	let sn =[];
	let product_serial_numbers = (serialNumbers.length) > 0 ? serialNumbers : $('#product_serial_numbers').val();
	if(consumed_sn != '' && (JSON.parse(product_serial_numbers).length) > 0){
		let serial_number = consumed_sn.split(',');
		serial_number.map(function(number){
			if(!(JSON.parse(product_serial_numbers)).includes(number.trim())) sn.push(number) ;
		});
		sn.length > 0 ? $("#warn_serial_number").show() : $("#warn_serial_number").hide();
	}
	else $("#warn_serial_number").hide();
}

function openReportPopup(){
	var popupUrl, periodType;
	var reportType = document.getElementById('report_type').value;
	var groupId = "", userId = "", actionType = "", projectId = "";
	if(document.getElementById('group_id')) {
		groupId = document.getElementById('group_id').value;
		userId = document.getElementById('user_id').value;
	}
	if(document.getElementById('action_type')) {
	   actionType = document.getElementById('action_type').value;
	}

	if(document.getElementById('project_id')) {
		projectId = document.getElementById('project_id').value;
	}

	var period = document.getElementById('period').value;
	var searchlist = document.getElementById('searchlist').value;
	var periodTypes = document.getElementsByName('period_type');
	var fromVal = document.getElementById('from').value;
	var toVal = document.getElementById('to').value;
	for (var i = 0, length = periodTypes.length; i < length; i++) {
		if (periodTypes[i].checked) {
			periodType = periodTypes[i].value
			break;
		}
	}

	popupUrl = wkattnReportUrl + '&report_type=' + reportType + '&group_id=' + groupId + '&action_type=' + actionType + '&user_id=' + userId + '&period_type=' + periodType + '&searchlist=' + searchlist + '&project_id=' + projectId;
	if(periodType>1){
		popupUrl = popupUrl + '&from=' + fromVal + '&to=' + toVal
	}else{
		popupUrl = popupUrl + '&period=' + period
	}
	window.open(popupUrl, '_blank', 'location=yes,scrollbars=yes,status=yes, resizable=yes');
}

function showReminderEmailDlg(title) {
	var teStatusOpt = document.getElementById('status').options;
	var isSubm = false;
	var isAppr = false;
	for(var i = 0; i < teStatusOpt.length; i++) {
		if (teStatusOpt[i].selected) {
			isSubm = (teStatusOpt[i].value == 'e' || teStatusOpt[i].value == 'n' || teStatusOpt[i].value == 'r');
			if(isSubm) {
				break;
			}
		}
	}
	for(var i = 0; i < teStatusOpt.length; i++) {
		if (teStatusOpt[i].selected) {
			isAppr = (teStatusOpt[i].value == 's');
			if(isAppr) {
				break;
			}
		}
	}
	var reminderEl = document.getElementsByName('reminder');
	if(!isSubm) {
		reminderEl[0].disabled = true;
	}
	if(!isAppr) {
		reminderEl[1].disabled = true;
	}
	if(!isSubm && !isAppr) {
		//disable Ok button if both submission and approval reminders is not applicable
		$("#btnOk").attr('disabled', true).addClass("ui-state-disabled");
	}
	for(var i = 0; i < reminderEl.length; i++) {
		if(!reminderEl[i].disabled) {
			reminderEl[i].checked = true;
			break;
		}
	}
	$( "#reminder-email-dlg" ).dialog('option', 'title', title).dialog( "open" );
}

function resetReminderEmailDlg() {
	document.getElementById('email_notes').value = "";
	var reminderEl = document.getElementsByName('reminder');
	for(var i = 0; i < reminderEl.length; i++) {
		reminderEl[i].checked = false;
		reminderEl[i].disabled = false;
	}
	$("#btnOk").attr('disabled', false).removeClass("ui-state-disabled");
	$('textarea').removeData('changed'); //for removing 'leave this page' warning
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
		success: function(data){ updateUserDD(data, userDropdown, userid, needBlankOption, false,"All Users", "0"); },
		beforeSend: function(){ $this.addClass('ajax-loading'); },
		complete: function(){ $this.removeClass('ajax-loading'); }
	});
}
function updateUserDD(itemStr, dropdown, userid, needBlankOption, skipFirst, blankText, blankval="")
{
	var items = itemStr.split('\n');
	var i, index, val, text, start;
	if(dropdown != null && dropdown.options != null){
		dropdown.options.length = 0;
		if(needBlankOption){
			dropdown.options[0] = new Option(blankText, blankval, false, false)
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
				val = val.replace(/_/g, ",");
				text = items[i].substring(index+1);
				dropdown.options[needBlankOption ? i+1 : i] = new Option(
					text, val, false, val == userid);
			}
		}
	}
}

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
function reportChanged(reportDD, userid){
	var id = reportDD.options[reportDD.selectedIndex].value;
	var needBlankOption = ((id == 'attendance_report' || id == 'spent_time_report' || id == 'payroll_rpt') ? true : false) ;
	grpChanged(document.getElementById("group_id"), userid, needBlankOption)
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
		success: function(data){ updateUserDD(data, userDropdown, userid, needBlankOption, false,"All Users", "0"); },
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

function accProjChanged(uid, fldId, isparent, blankOptions)
{
	var acc_name = document.getElementById(fldId);
	var parentId = 0
	if( acc_name.length > 0)
	{
		parentId = acc_name.options[acc_name.selectedIndex].value;
	}
	var parentType = "WkAccount";
	var $this = $(this);
	if(isparent)
	{
		var parentDD = document.getElementById('related_to');
		parentType = parentDD.options[parentDD.selectedIndex].value;
	} else {
		if(fldId == 'contact_id' && parentId != "")
			parentType = 'WkCrmContact'
		else if( fldId == 'lead_id' && parentId != "")
			parentType = 'WkLead';
		else
			parentType = 'WkAccount';
	}
	var needBlankOption = blankOptions;
	var projDropdown = document.getElementById("project_id");
	userid = uid;
	$.ajax({
	url: accountUrl,
	type: 'get',
	data: {parent_id: parentId, parent_type: parentType},
	success: function(data){ updateUserDD(data, projDropdown, userid, needBlankOption, false, "");},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ $this.removeClass('ajax-loading'); }
	});
}

function actRelatedDd(uid, loadProjects, needBlankOption, actType, contactType, loadPayment, loadInvoiceNo = false, loadSIDD = '')
{
	var relatedTo = document.getElementById("related_to");
	var relatedType = relatedTo.options[relatedTo.selectedIndex].value;
	var relatedparentdd = document.getElementById("related_parent");
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: actRelatedUrl,
	type: 'get',
	data: {related_type: relatedType, account_type: actType, contact_type: contactType},
	success: function(data){ updateUserDD(data, relatedparentdd, userid, needBlankOption, false, "");if(loadInvoiceNo){get_invoice_no(uid, loadSIDD);}},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ if(loadProjects) { accProjChanged(uid, 'related_parent', true, true) }if(loadPayment){submitFiletrForm();} $this.removeClass('ajax-loading'); }
	});
}

function parentChanged(uid)
{
	var parentType = document.getElementById("related_to");
	var parentTypeVal = parentType.options[parentType.selectedIndex].value;
	var parentDD = document.getElementById("related_parent");
	var parentId = parentDD.options[parentDD.selectedIndex].value;
	var needBlankOption = true;
	var projDropdown = document.getElementById("project_id");
	userid = uid;
	$.ajax({
	url: paymentUrl,
	type: 'get',
	data: {related_to: parentTypeVal, related_parent: parentId},
	success: function(data){ updateUserDD(data, projDropdown, userid, needBlankOption, false, "");},
	});
}

function submitFiletrForm()
{
	document.getElementById("invoice_form").submit();
}

function rfqTOQuoteChanged(uid, loadDdId)
{
	var rfqDD = document.getElementById("rfq_id");
	var rfqId = rfqDD.options[rfqDD.selectedIndex].value;
	var parentId = "", ParentType = "WkAccount";
	if(document.getElementById("polymorphic_filter_2").checked)
	{
		var contactDD = document.getElementById("contact_id");
		parentId = contactDD.options[contactDD.selectedIndex].value;
		ParentType = "WkCrmContact";
	}
	else
	{
		var actDD = document.getElementById("account_id");
		parentId = actDD.options[actDD.selectedIndex].value;
	}
	var loadDropdown = document.getElementById(loadDdId);
	var needBlankOption = false;
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: rfqQuoteUrl,
	type: 'get',
	data: {rfq_id: rfqId, parent_id: parentId, parent_type: ParentType},
	success: function(data){ updateUserDD(data, loadDropdown, userid, needBlankOption, false, "");},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ $this.removeClass('ajax-loading'); }
	});
}

function dateRangeValidation(fromId, toId)
{
	var fromElement = document.getElementById(fromId);
	var toElement = document.getElementById(toId);
	var fromdate = new Date(fromElement.value);
	var todate = new Date(toElement.value);
	var d = new Date();
	if(fromdate > todate)
	{
		fromElement.value = fromElement.defaultValue;
		d.setDate(fromdate.getDate()+30);
		d.setMonth(d.getMonth()+1);
		toElement.value = d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate();
		alert(" End date should be greater then start date ");
	}

}

function productCategoryChanged(changeDDId, uid, logType)
{
	//var currDD = document.getElementById(curDDId);
	var needBlankOption = false;
	var changeDD = document.getElementById(changeDDId);
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: productModifyUrl,
	type: 'get',
	data: {ptype: changeDDId, log_type: logType, product_id: changeDD.value },
	success: function(data){ updateUserDD(data, changeDD, userid, needBlankOption, false, "");},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ productChanged('product', 'product_item', uid, true, false, 'log_type'); $this.removeClass('ajax-loading'); }
	});
}

function productChanged(curDDId, changeDDId, uid, changeAdditionalDD, needBlank, logTypeId, locationId)
{
	var currDD = document.getElementById(curDDId);
	var needBlankOption = needBlank;
	var changeDD = document.getElementById(changeDDId);
	var productId;
	var updateDD;
	var logType = 'I';
	var locId;
	if(changeDDId == 'product_model_id'){
		var productDD = document.getElementById('product_id');
		productId = productDD.value;
	}
	if(curDDId.includes("product_id")){
		rowNum = curDDId.replace("product_id","")
		if(changeDDId.includes("product_attribute_id")){
			updateDD = "product_attribute_id"
			changeDD = document.getElementById("product_attribute_id"+rowNum);
		}
		if(changeDDId.includes("product_item_id")){
			updateDD = "product_item_id"
			changeDD = document.getElementById("product_item_id"+rowNum);
		}
		if(changeDDId.includes("product_type")){
			updateDD = "product_type"
			changeDD = document.getElementById("product_type"+rowNum);
		}
		var productDD = document.getElementById(curDDId);
		productId = productDD.value;
	}
	if(logTypeId != null)
	{
		logTypeVal = document.getElementById(logTypeId).value;
		logType = logTypeVal == 'M' ? 'I' : logTypeVal;
	}
	if(locationId != null)
	{
		locId = document.getElementById(locationId).value;
	}
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: productModifyUrl,
	type: 'get',
	data: {id: currDD.value, ptype: changeDDId, product_id: productId, update_DD: updateDD, log_type: logType, location_id: locId },
	success: function(data){ updateUserDD(data, changeDD, userid, needBlankOption, false, "");},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){
		if(changeAdditionalDD && changeDDId == 'brand_id'){
			productChanged('brand_id','product_model_id', uid, false, true, null);
			productChanged('product_id','product_attribute_id', uid, false, true, null);
		}
		else if(changeAdditionalDD && logTypeId != null ){
			productItemChanged('product_item', 'product_quantity', 'product_cost_price', 'product_sell_price', uid, 'log_type');
		}
		else if(changeAdditionalDD && (changeDDId.includes("product_item_id")) ){
			deliveryitemChanged('product_item_id'+rowNum);
		}
		  $this.removeClass('ajax-loading'); }
	});
}

function productAssetChanged(curDDId, changeDDId, uid, needBlank)
{
	var currDD = document.getElementById(curDDId);
	var needBlankOption = needBlank;
	var changeDD = document.getElementById(changeDDId);
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: productAssetUrl,
	type: 'get',
	data: {id: currDD.value },
	success: function(data){ updateUserDD(data, changeDD, userid, needBlankOption, false, "");},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){  $this.removeClass('ajax-loading'); }
	});
}

function productUOMChanged(curDDId, changeDDId, uid)
{
	var currDD = document.getElementById(curDDId);
	var needBlankOption = false;
	var changeDD = document.getElementById(changeDDId);
	var productDD = document.getElementById('product');
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: productModifyUrl,
	type: 'get',
	data: {id: currDD.value, ptype: changeDDId, product_id: productDD.value },
	success: function(data){ updateUserDD(data, changeDD, userid, needBlankOption, false, "");},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){  $this.removeClass('ajax-loading'); }
	});
}

function productItemChanged(curDDId, qtyDD, cpDD, spDD, uid, logTypeId)
{
	var currDD = document.getElementById(curDDId);
	var needBlankOption = false;
	var productDD = document.getElementById('product');
	var $this = $(this);
	var logType = 'I';
	userid = uid;
	if(logTypeId != null)
	{
		logTypeVal = document.getElementById(logTypeId).value;
		if(logTypeVal == 'M')
		{
			logType =  'I';
		}
		else {
			logType = logTypeVal
		}
	}

	$.ajax({
	url: productModifyUrl,
	type: 'get',
	data: {id: currDD.value, ptype: 'inventory_item', product_id: productDD.value, log_type: logType },
	success: function(data){
		if(logType == 'I' && data != ""){
			var pctData = data.split(',');
			var product_serial_numbers = [];
			if( pctData[6] && !isNaN(pctData[6])) product_serial_numbers = getSerialNumbersRange(pctData[5], pctData[6], pctData[7]);
			$('#product_serial_numbers').val(JSON.stringify(product_serial_numbers));
			$('#material_sn').val('');
			$('#warn_serial_number').hide();
		}
		setProductLogAttribute(data, qtyDD, cpDD, spDD, logType);
	},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ productUOMChanged(curDDId, 'uom_id', uid); $this.removeClass('ajax-loading'); }
	});
}

function setProductLogAttribute(data, qtyDD, cpDD, spDD, logType)
{
	if(data != "")
	{
		var pctData = data.split(',');
		document.getElementById('available_quantity').innerHTML = pctData[1];
		document.getElementById(qtyDD).value  = 1;//pctData[1];
		if(document.getElementById(cpDD) != null)
		{
			document.getElementById(cpDD).value = parseFloat(pctData[2]).toFixed(2);
			document.getElementById('cpcurrency').innerHTML = pctData[3];
		}

		document.getElementById('spcurrency').innerHTML = pctData[3];
		spVal = pctData[4] == "" ? "" : parseFloat(pctData[4]).toFixed(2);
		document.getElementById(spDD).value = spVal;
		document.getElementById('inventory_item_id').value = pctData[0];
		document.getElementById('total').innerHTML = pctData[3] + (parseFloat(pctData[4] * 1).toFixed(2));
		if(logType != 'I')
		{
			document.getElementById('unittext').innerHTML = pctData[5];
		}
		else{
			document.getElementById('unittext').innerHTML = "";
		}

	}
	else
	{
		document.getElementById(qtyDD).value  = "";
		if(document.getElementById(cpDD) != null)
		{
			document.getElementById(cpDD).value = "";
		}
		document.getElementById(spDD).value = "";
		document.getElementById('inventory_item_id').value = "";
		document.getElementById('total').innerHTML = "";
		document.getElementById('unittext').innerHTML = "";
	}

}

function getSupplierInvoice(uid, loadDdId)
{
	var parentId = "", ParentType = "WkAccount";
	if(document.getElementById("polymorphic_filter_2").checked)
	{
		var contactDD = document.getElementById("contact_id");
		parentId = contactDD.options[contactDD.selectedIndex].value;
		ParentType = "WkCrmContact";
	}
	else
	{
		var actDD = document.getElementById("account_id");
		parentId = actDD.options[actDD.selectedIndex].value;
	}
	var loadDropdown = document.getElementById(loadDdId);
	var needBlankOption = true;
	userid = uid;
	var $this = $(this);
	$.ajax({
	url: siUrl,
	type: 'get',
	data: {parent_id: parentId, parent_type: ParentType},
	success: function(data){ updateUserDD(data, loadDropdown, userid, needBlankOption, false, "");},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ $this.removeClass('ajax-loading'); }
	});
}

function hideLogDetails(uid)
{
	var logType = document.getElementById("log_type").value;
	var oldLogType = document.getElementById("old_log_type").value;
    var entry = 'time_entry'
    if(logType == 'E') entry = 'wk_expense_entry';
    if(['M', 'A', 'RA'].includes(logType)) entry = 'wk_material_entry';
	$('input[name*="'+oldLogType+'"], select[name^="'+oldLogType+'"]').each(function(){
		let name = (this.name).replace(oldLogType, entry);
		let id = (this.id).replace(oldLogType, entry);
		this.name = name;
		this.id = id;
	})
	var hours_label = oldLogType + '_hours'
	$('label[for="'+hours_label+'"]').attr('for',entry+'_hours');
	if(logType == 'T')
	{
		document.getElementById('time_entry_hours').style.display = 'block';
		$('label[for="time_entry_hours"]').css('display', 'block');
		if(document.getElementById("spent_for_tbl")){
			document.getElementById("spent_for_tbl").style.display = 'block';
		}
		//$('label[for="time_entry_hours"]').html('Hours<span style="color:red;">*</span>');
		document.getElementById("materialtable").style.display = 'none';
		document.getElementById("expensetable").style.display = 'none';
		$('#issuelogtable').show();
		$('#geolocation').show();
		$('.start_on, .end_on').prop('onchange', 'calculateHours()');
	}
	else if(logType == 'E') {
		document.getElementById('wk_expense_entry_hours').style.display = 'none';
		$('label[for="wk_expense_entry_hours"]').css('display', 'none');
		//$('label[for="time_entry_hours"]').html('Amount<span style="color:red;">*</span>');
		document.getElementById("materialtable").style.display = 'none';
		if(document.getElementById("spent_for_tbl")){
			document.getElementById("spent_for_tbl").style.display = 'none';
		}
		document.getElementById("expensetable").style.display = 'block';
		$('#issuelogtable').hide();
		$('#geolocation').show();
		$('.start_on, .end_on').val('');
		$('.start_on, .end_on').prop('onchange', null);
	}
	else
	{
		document.getElementById('wk_material_entry_hours').style.display = 'none';
		$('label[for="wk_material_entry_hours"]').css('display', 'none');
		document.getElementById("expensetable").style.display = 'none';
		if(document.getElementById("spent_for_tbl")){
			document.getElementById("spent_for_tbl").style.display = 'block';
		}
		document.getElementById("materialtable").style.display = 'block';
		if(uid != null) {
			productCategoryChanged('product', uid, logType);
		}
		if(logType == 'A') $('#issuelogtable').show();
		if(logType == 'M') $('#issuelogtable').hide();
		if(logType == 'M') $('#material_serial_no').show();
		if(logType != 'M') $('#material_serial_no').hide();
		if(logType == 'M' || logType == 'A'){
			$('#geolocation').show();
		} else {
			$('#geolocation').hide();
		}
		$('.start_on, .end_on').val('');
		$('.start_on, .end_on').prop('onchange', null);
	}
	$('#old_log_type').val(entry);

}

function depreciatonFormSubmission()
{
	var dateval = new Date(document.getElementById("to").value);
	var fromdateval = new Date(document.getElementById("from").value);
	//dateval.setDate(dateval.getDate() + 1);
	var toDateStr = dateval.getFullYear() + '-' + (("0" + (dateval.getMonth() + 1)).slice(-2)) + '-' + (("0" + dateval.getDate()).slice(-2));
	var fromDateStr = fromdateval.getFullYear() + '-' + (("0" + (fromdateval.getMonth() + 1)).slice(-2)) + '-' + (("0" + fromdateval.getDate()).slice(-2));
	if (isNaN(dateval.getFullYear()) || isNaN(fromdateval.getFullYear())){
		alert("Please select valid date range");
	}
	else {
		var isFormSubmission = confirm(apply_warn + " " + fromDateStr + " to " + toDateStr);
		if (isFormSubmission == true) {
			document.getElementById("generate").value = true;
			document.getElementById("query_form").submit();
		}
	}

}

function scheduleFormSubmission()
{
	var isFormSubmission = confirm(apply_warn);
	if (isFormSubmission == true) {
		document.getElementById("generate").value = true;
		$('#ajax-indicator').show();
		$("#schedule_form").submit();
		document.getElementById("generate").value = false;
	}

}


function validateAsset()
{
	var valid=true;
	var assetDropdown = document.getElementById("inventory_item_id");
	if (assetDropdown.value=="")
	{
		valid=false;
		alert(no_asset);
	}
	return valid;
}
/*
function showorHide(isshow, divId)
{
	if(!isshow)
	{
		document.getElementById(divId).style.disabled = true;
	}
	else {
		document.getElementById(divId).style.disabled = false;
	}
}*/

function sheetViewChange(field)
{
	if(field.value != "")
	{
		if(field.value == "I")
		{
			showorHide(true, 'spentForLbl', 'spent_for_key');
			showorHide(true, 'issueLbl', 'issue_id');
		}
		else {
			showorHide(false, 'spentForLbl', 'spent_for_key');
			showorHide(false, 'issueLbl', 'issue_id');
		}
	}
}

function userChanged(userDropdown, needBlank){

	var userDD = document.getElementById('user_id');
	var sheetViewDD = document.getElementById('sheet_view');

	if(userDD != null && sheetViewDD != null && sheetViewDD.value == "I")
	{

		var issDropdown = document.getElementById("issue_id");
		var clientDropdown = document.getElementById("spent_for_key");
		var issUrl = document.getElementById("getuser_issues_url").value;
		var clientUrl = document.getElementById("getuser_clients_url").value;
		var fmt = 'text';
		var uid = document.getElementById("user_id").value;
		var $this = $(this);
		$.ajax({
			url: issUrl,
			type: 'get',
			data: {user_id: userDD.value, format:fmt},
			success: function(data){
				updateUserDD(data, issDropdown, userDD.value, needBlank, false,"");
			},
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading'); }
		});

		$.ajax({
			url: clientUrl,
			type: 'get',
			data: {user_id: userDD.value, format:fmt},
			success: function(data){
				//var actId = getDefaultActId(data);
				//var items = data.split('\n');
				//var needBlankOption = !(items.length-1 == 1 || actId != null);
				updateUserDD(data, clientDropdown, userDD.value, needBlank, false,"");
			},
			beforeSend: function(){ $this.addClass('ajax-loading'); },
			complete: function(){ $this.removeClass('ajax-loading'); }
		});
	}
}

function loadSpentFors(id, Dropdown, needBlank, uid)
{
	var clientDropdown = document.getElementById(Dropdown);
	var $this = $(this);
	var fmt = 'text';
	$.ajax({
		url: getClientsUrl,
		type: 'get',
		data: {project_id: id, user_id: uid, format:fmt},
		success: function(data){updateUserDD(data, clientDropdown, uid, needBlank, false,"");
		},
		beforeSend: function(){ $this.addClass('ajax-loading'); },
		complete: function(){ $this.removeClass('ajax-loading'); }
	});
}

function myReportUser(optionID,userID){
	var userDropdown = document.getElementById("user_id");
	var fmt = 'text';
	var $this = $(this);
	var value = optionID.value;
	$.ajax({
		url: userCurrentUrl,
		type: 'get',
		data: { filter_type:value, user_id: userID, format:fmt},
		success: function(data){ updateUserDD(data, userDropdown, userID, true, false, "All Users"); },
		beforeSend: function(){ $this.addClass('ajax-loading'); },
		complete: function(){ $this.removeClass('ajax-loading'); }
	});
}

function reportersChanged(ele){
	switch(ele.value){
		case '3':
			$("#group_id").attr("disabled", true);
			$("#project_id").attr("disabled", true);
			$("#user_id").attr("disabled", true);
		break;
		case '4':
			myReportUser(ele,"#{User.current.id}");
			$("#group_id").attr("disabled", true);
			$("#project_id").attr("disabled", true);
			$("#user_id").removeAttr("disabled");
		break;
		case '5':
			myReportUser(ele,"#{User.current.id}");
			$("#group_id").attr("disabled", true);
			$("#project_id").attr("disabled", true);
			$("#user_id").removeAttr("disabled");
		break;
	}
}

function getprojects(ele, isAccProj, isSIProj){
	switch(ele.value){
		case '2': ddeleID = 'contact_id'
		break;
		case '3': ddeleID = 'account_id'
		break;
		case '4': ddeleID = 'lead_id'
		break;
		default : ddeleID = ele.id
	}
	if(isAccProj){
		accProjChanged('', ddeleID, false, true);
	}
	if(isSIProj){
		getSupplierInvoice('', 'si_id')
	}
}

function hideSummaryDD(value) {
    if(value != ""){
		$( "#trans_summary" ).show();
	}
	else{
		$("#summary_trans").val("days");
		$( "#trans_summary" ).hide();
	}
}

function profitLossAmount(disposeAmnt)
{
	var currentVal = $('#asset_current_value').val();
	var currency = $('#currency').val();
	var profitLossAmnt = 0;
	if(disposeAmnt != "")
	{
		profitLossAmnt = disposeAmnt - currentVal;
	}
	profit_loss = currency + " " + profitLossAmnt.toFixed(2);
	$("#profit_loss").html(profit_loss);
}

function setUOMValue(product_id)
{
	var productId = document.getElementById(product_id).value;
	rowNum = product_id.replace("product_id","")
	var url = "/wkshipment/get_product_uom?product_id="+ productId;
	$.ajax({
		url: url,
		type: 'get',
		success: function(data){ $('#uom_id'+rowNum).val(data); },
		beforeSend: function(){ $(this).parent().addClass('ajax-loading'); },
		complete: function(){ $(this).parent().removeClass('ajax-loading'); }
	});
}

function renderData(resData, options={}){
	let {id="#dialog", clear=true, type, preHeader, preList, title} = options;
	let content = title && "<h2>"+title+"</h2>" || "";
	const {header={}, data=[]} = resData || {};
	if(data.length > 0){
		content += "<table class='list time-entries' style='width:100%; float:left;'>";
		//Headers
		content += "<tr>";
		if(preHeader) content += preHeader(type);

		$.each(header, function(key, label){
			content += "<th class='th'>" +label+ "</th>";
		});
		content += "</tr>";

		//List
		$.each((data), function(inx, el){
			content += "<tr>";
			if(preList) content += preList(type, el);

			$.each((el || {}), function(key, value){
				if(key == 'icon'){
					content += "<td class='td'><a class='icon' href='"+value+ "'>"+ details +"</a></td>";
				}
				else{
					content += "<td class='td'>" +value+ "</td>";
				}
			});
			content += "</tr>";
		});
		content += "</table>";
	} else{
		content += '<p style="clear:both" class="nodata">'+label_no_data+'</p>';
	}
	if(!$(id).length){
		$("body").append("<div id='dialog'></div>")
	} else if(clear){
		$(id).html("");
	}
	$(id).append(content);
}

function setOverHeadCost(aval_quantity){
	var aval_quantity = $('#available_quantity').val();
	var over_head = $('#per_over_head').val();
	var data = over_head *  aval_quantity;
	$('#over_head_price').val(data.toFixed(2));
	$('#transfer_over_head').val(data.toFixed(2));
}

function getAssignedSNs(){
	let serial_number = $('#serial_number').val();
	let running_sn = $('#running_sn').val();
	let total_quantity = $('#total_quantity').val();
	populateSerialNos(serial_number, running_sn, total_quantity);
}

function populateSerialNos(serial_number, running_sn, total_quantity){
	let content = "";
	let org_total_quantity = total_quantity;
	let org_sn_length = running_sn.length;
	if(total_quantity > 50) total_quantity = 50;

	if(running_sn && isNaN(running_sn)){
		content += '<p style="clear:both" class="nodata">'+ sn_text_error +'</p>';
	}
	else if(!running_sn && serial_number == ''){
		content += '<p style="clear:both" class="nodata">'+ sn_blank_error +'</p>';
	}
	else{
		let serialNumbers = getSerialNumbersRange(serial_number, running_sn, total_quantity);
		content = "<table>";
		serialNumbers.map(function(number){
				content += "<tr><td style='width:100%;'>" + number + "</td></tr>";
			});
		if(org_total_quantity > 50){
			content += "<tr><td style='width:100%;'> .... </td></tr><tr><td style='width:100%;'> .... </td></tr>";
			if(running_sn) running_sn = Number(running_sn) + Number(org_total_quantity) - 1;
			content += "<tr><td style='width:100%;'>" + serial_number + String(running_sn).padStart(org_sn_length, '0') + "</td></tr>";
		}
		content += "</table>";
	}

	if(!$("#dialog").length){
		$("body").append("<div id='dialog'></div>")
	}
	else{
		$("#dialog").html("");
	}
	$("#dialog").append(content);

	$("#dialog" ).dialog({
		modal: true,
		title: 'Assigned serial numbers',
		width: "20%",
		height: 500,
	});
}

function getSerialNumbersRange(serial_number, running_sn, total_quantity){
	let serialNumbers = [];
	let org_sn_length = running_sn.length;
	for(i = 0; i < Number(total_quantity); i++){
		serialNumbers.push(serial_number + running_sn);
		if(running_sn){
			running_sn = Number(running_sn) + 1;
			if(String(running_sn).length < org_sn_length) running_sn = String(running_sn).padStart(org_sn_length, '0');
		}
	}
	return serialNumbers;
}

function exportReport(format){
	$('#query_form').append('<input type="hidden" name="format" value='+format+' /> ');
	$('#query_form').submit();
}

function locationChanged(locationId, uid){
	rowNum = locationId.replace("location_id","");
	productChanged('product_id'+rowNum, 'product_item_id'+rowNum, uid, true, false, null, locationId);
}

function deliveryitemChanged(curDDId)
{
	var currDD = document.getElementById(curDDId);
	rowNum = curDDId.replace("product_item_id","");
	var $this = $(this);
	var updateDD = "inventory_item";

	$.ajax({
	url: productModifyUrl,
	type: 'get',
	data: {id: currDD.value, update_DD: updateDD },
	success: function(data){
		if(data != "")
		{
			var pctData = data.split(',');
			$('#total_quantity'+rowNum).val(pctData[1]);
			$('#selling_price'+rowNum).val(parseFloat(pctData[3]).toFixed(2));
			$('#currency'+rowNum).val(pctData[5]);
			$('#serial_number'+rowNum).val(pctData[6]);
			$('#running_sn'+rowNum).val(pctData[7]);
			$('#uom_id'+rowNum).val(pctData[8]);
			$('#cost_price'+rowNum).html(parseFloat(pctData[2]).toFixed(2));
			$('#over_head_price'+rowNum).html(parseFloat(pctData[4]).toFixed(2));
		}
		else
		{
			$('#total_quantity'+rowNum).val("");
			$('#selling_price'+rowNum).val("");
			$('#currency'+rowNum).val("");
			$('#serial_number'+rowNum).val("");
			$('#running_sn'+rowNum).val("");
			$('#uom_id'+rowNum).val("");
			$('#cost_price'+rowNum).html("");
			$('#over_head_price'+rowNum).html("");
		}
	},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ $this.removeClass('ajax-loading'); }
	});
}

function get_invoice_no(uid, loadDdId){
	var parentType = $('#related_to').val();
	var parentId = $('#related_parent').val();
	var needBlankOption = false;
	var loadDropdown = document.getElementById(loadDdId);
	$.ajax({
		url: invoiceUrl,
		type: 'get',
		data: {parent_id: parentId, parent_type: parentType},
		success: function(data){updateUserDD(data, loadDropdown, uid, needBlankOption, false, "");
		if(loadDdId == 'delivery_invoice_id') $('#populate_items').hide();
		},
		beforeSend: function(){ $(this).addClass('ajax-loading'); },
		complete: function(){ $(this).removeClass('ajax-loading'); }
	});
}

function populateInvoice()
{
	let url = new URL(window.location.href);
	url.searchParams.set('related_to', $('#related_to').val());
	url.searchParams.set('related_parent', $('#related_parent').val());
	url.searchParams.set('delivery_invoice_id', $('#delivery_invoice_id').val());
	url.searchParams.set('populate_items', 'true');
	location.href = url;
}

function showHidePartNumber(){
	if($("#automatic_product_item").prop("checked")){
		$("#tr_part_number").show();
	}
	else{
		$("#tr_part_number").hide();
	}
}

function getReceiptAssignedSNs(elementId){
	var rowNum = elementId.replace("running_sn_","");
	let serial_number = $('#serial_number_'+rowNum).val();
	let running_sn = $('#running_sn_'+rowNum).val();
	let total_quantity = $('#total_quantity_'+rowNum).val();
	populateSerialNos(serial_number, running_sn, total_quantity);
}

function populateSIInvoice()
{
  if (confirm("Are you sure change the invoice this will populate invoice item")) {
		let url = new URL(window.location.href);
		url.searchParams.set('related_to', $('#related_to').val());
		url.searchParams.set('related_parent', $('#related_parent').val());
		url.searchParams.set('si_id', $('#si_id').val());
		url.searchParams.set('populate_items', '1');
		location.href = url;
  }
	else{
		$('#si_id').val($('#prev_si_id').val())
	}
}

function submitReceiptForm(){
	var ret = true;
	var url = "/wkshipment/check_quantity";
	var si_id = $('#si_id').val();
	var inv_item_id = $('#availabelInvIds').val()
	if(si_id > 0){
		$('[id^=invoice_item_id]').attr('required', '');
		$.ajax({
			url: url,
			type: 'get',
			data: {si_id: si_id, inv_item_id: inv_item_id},
			async: false,
			success: function(data){
				var received_qty = receivedQuantitySum(data)
				if(data.invoice_qty < received_qty){
					var confirmMsg = confirm('Invoice quantity is higher than received quantity')
					if(confirmMsg){
						ret =  true;
					}
					else{
						ret = false;
					}
				}
			},
			beforeSend: function(){ $(this).addClass('ajax-loading'); },
			complete: function(){ $(this).removeClass('ajax-loading'); }
		});
	}
	return ret;
}

function receivedQuantitySum(data){
	var current_quantity = $('[id^=total_quantity]');
	var quantity_sum = 0;
	current_quantity.each(function(e) {
	if(!$('#item_id_'+(e+1)).val())
		quantity_sum += parseInt($(this).val());
	});
	quantity_sum += data.received_qty
	return quantity_sum
}

function populateAsset()
{
	let url = new URL(window.location.href);
	url.searchParams.set('inventory_item_id', $('#existing_id').val());
	location.href = url;
}

function getAssembleItem(){
	$("#quantity").val('');
	$("#serial_no").val('');
	$("#product_item").val('');
	$("#avail_quantity").html('');
	$("#assembleItem").dialog("open");
}

function deleteItemRow(index){
	let isDelete = confirm("Are you sure want to delete");
		if (isDelete) {
			$("#assembleItemTable tr:eq("+index+")").remove();
		}
}

function itemChanged(id)
{
	$.ajax({
	url: productItemUrl,
	type: 'get',
	data: {id: id },
	success: function(data){
		let item = data.item;
		let product_serial_numbers = [];
		if(item.running_sn) product_serial_numbers = getSerialNumbersRange(item.serial_number, item.running_sn, item.total_quantity);
		$('#product_serial_numbers').val(JSON.stringify(product_serial_numbers));
		$('#item_avail_quantity').val(item.available_quantity);
		$('#avail_quantity').html(item.available_quantity);
		$('#serial_no').val('');
		$('#quantity').val('');
		$('#warn_serial_number').hide();
	},
	beforeSend: function(){ $(this).addClass('ajax-loading'); },
	complete: function(){ $(this).removeClass('ajax-loading'); }
	});
}