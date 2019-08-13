var wktimeIndexUrl, wkexpIndexUrl, wkattnIndexUrl,wkReportUrl,clockInOutUrl, payrollUrl, blgaccUrl, blgcontractsUrl, blgaccpjtsUrl, blginvoiceUrl, blgtaxUrl, blgtxnUrl, blgledgerUrl, crmleadsUrl, crmopportunityUrl, crmactivityUrl, crmcontactUrl, crmenumUrl, blgpaymentUrl, blgexcrateUrl, purRfqUrl, purQuoteUrl, purPurOrderUrl, purSupInvUrl, purSupAccUrl, purSupContactUrl, purSupPayUrl, wklocationUrl,  wkproductUrl, wkproductitemUrl, wkshipmentUrl, wkassetUrl, wkassetdepreciationUrl, wkgrpPermissionUrl, wkSchedulingUrl, wkPublicHolidayUrl, userCurrentUrl, wkSurveyUrl; 
var no_user ="";
var grpUrl="";
var userUrl="";
var accountUrl ="";
var userList = new Array();
var rSubEmailUrl = "";
var rAppEmailUrl = "";

$(document).ready(function() {
	$( "#reminder-email-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: true,
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
});

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

function showReminderEmailDlg() {
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
	$( "#reminder-email-dlg" ).dialog( "open" );
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
		success: function(data){ updateUserDD(data, userDropdown, userid, needBlankOption, false,"All Users"); },
		beforeSend: function(){ $this.addClass('ajax-loading'); },
		complete: function(){ $this.removeClass('ajax-loading'); }
	});	
}
function updateUserDD(itemStr, dropdown, userid, needBlankOption, skipFirst, blankText)
{	
	var items = itemStr.split('\n');
	var i, index, val, text, start;
	if(dropdown != null && dropdown.options != null){
		dropdown.options.length = 0;
		if(needBlankOption){
			dropdown.options[0] = new Option(blankText, "0", false, false) 
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
}
$(document).ready(function()
{
	changeProp('tab-wktime',wktimeIndexUrl);
	changeProp('tab-wkexpense',wkexpIndexUrl);
	changeProp('tab-leave',wkattnIndexUrl);
	changeProp('tab-clock',clockInOutUrl);
	changeProp('tab-payroll',payrollUrl);
	//changeProp('tab-usersettings',userssettingsUrl);
	changeProp('tab-wkcrmaccount',blgaccUrl);
	changeProp('tab-wkcontract',blgcontractsUrl);
	changeProp('tab-wkaccountproject',blgaccpjtsUrl);
	changeProp('tab-wkinvoice',blginvoiceUrl);
	changeProp('tab-wktax',blgtaxUrl);
	changeProp('tab-wkgltransaction',blgtxnUrl);
	changeProp('tab-wkledger',blgledgerUrl);
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
	changeProp('tab-wkpublicholiday',wkPublicHolidayUrl);
	changeProp('tab-wksurvey',wkSurveyUrl);
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
		success: function(data){ updateUserDD(data, userDropdown, userid, needBlankOption, false,"All Users"); },
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
		parentType = fldId == 'contact_id' && parentId != "" ? 'WkCrmContact' : ( fldId == 'account_id' && parentId != "" ? 'WkAccount' : '');
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

function actRelatedDd(uid, loadProjects, needBlankOption, actType, contactType, loadPayment)
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
	success: function(data){ updateUserDD(data, relatedparentdd, userid, needBlankOption, false, "");},
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
	complete: function(){ if(changeAdditionalDD && changeDDId == 'brand_id'){productChanged('brand_id','product_model_id', uid, false, true, null);productChanged('product_id','product_attribute_id', uid, false, true, null);} else if(changeAdditionalDD && logTypeId != null ){productItemChanged('product_item', 'product_quantity', 'product_cost_price', 'product_sell_price', uid, 'log_type'); }  $this.removeClass('ajax-loading'); }	      
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
	success: function(data){ setProductLogAttribute(data, qtyDD, cpDD, spDD);},
	beforeSend: function(){ $this.addClass('ajax-loading'); },
	complete: function(){ productUOMChanged(curDDId, 'uom_id', uid); $this.removeClass('ajax-loading'); }	      
	});
}

function setProductLogAttribute(data, qtyDD, cpDD, spDD)
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
		if(pctData[5] != "")
		{
			document.getElementById('unittext').innerHTML = pctData[5]  ;
		}
		else{
			document.getElementById('unittext').innerHTML = ""  ;
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
	}
	else if(logType == 'E') {
		document.getElementById('time_entry_hours').style.display = 'none';
		$('label[for="time_entry_hours"]').css('display', 'none');
		//$('label[for="time_entry_hours"]').html('Amount<span style="color:red;">*</span>');
		document.getElementById("materialtable").style.display = 'none';
		if(document.getElementById("spent_for_tbl")){
			document.getElementById("spent_for_tbl").style.display = 'none';
		}
		document.getElementById("expensetable").style.display = 'block';
	}
	else 
	{		
		document.getElementById('time_entry_hours').style.display = 'none';
		$('label[for="time_entry_hours"]').css('display', 'none');
		document.getElementById("expensetable").style.display = 'none';
		if(document.getElementById("spent_for_tbl")){
			document.getElementById("spent_for_tbl").style.display = 'block';
		}
		document.getElementById("materialtable").style.display = 'block';
		if(uid != null) {
			productCategoryChanged('product', uid, logType);
		}
	}
	
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

function getprojects(ele, isAccProj, isSIProj){
	switch(ele.value){
		case '2': ddeleID = 'contact_id'
		break;
		case '3': ddeleID = 'account_id'
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