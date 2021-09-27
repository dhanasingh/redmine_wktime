var row_id = 0;
var compId = 0;

$(document).ready(function() {
	$('.date').each(function() {
			$(this).datepicker({ dateFormat: 'yy-mm-dd' });
	});
	hideProductType()


	$("form").submit(function() {
		var invComplistbox=document.getElementById("invoice_components");
		if(invComplistbox != null){
			for(i = 0; i < invComplistbox.options.length; i++){
				invComplistbox.options[i].selected = true;
			}
		}

	});

	$( "#invcomp-dlg" ).dialog({
		autoOpen: false,
		resizable: true,
		width: 380,
		modal: false,
		buttons: {
			"Ok": function() {
				var opt,desc="",opttext="";
				var listBox = document.getElementById(listboxId);
				var invCompName = document.getElementById("inv_copm_name");
				var invCompVal = document.getElementById("inv_copm_value");
				if(invCompName.value != ""){
					if('Add'== leaveAction){
						opt = document.createElement("option");
						listBox.options.add(opt);
					}
					else if('Edit' == leaveAction){
						opt = listBox.options[listBox.selectedIndex];
					}
					if (invCompName.value != ""){
						desc = invCompName.value
						opttext = desc + ":"  + invCompVal.value;
						desc = ( (compId != 0 && leaveAction == 'Edit') ?  compId + "|" : "|" ) + desc + "|"  + invCompVal.value;
					}
					opt.text =  opttext;
					opt.value = desc;
					$( this ).dialog( "close" );
				}
				else{
					var alertMsg = "";
					if(invCompName.value == ""){
						alertMsg = lblInvCompName + " "+ lblInvalid + "\n";
					}
					alert(alertMsg);
				}
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});
});

function invoiceFormSubmission(isPreview)
{
	var timeentryIDs = $('input[name=check_time_entries]:checked').map(function(){
 		return $(this).val();
  }).get();
	var materialentryIDs = $('input[name=check_material_entries]:checked').map(function(){
 		return $(this).val();
  }).get();
	let expenseEntryIDs = $('input[name=check_wk_expense_entries]:checked').map(function(){
 		return $(this).val();
  }).get();
	$("input#timeEntryIDs").val(timeentryIDs);
	$("input#materialEntryIDs").val(materialentryIDs);
	$("input#expenseEntryIDs").val(expenseEntryIDs);
	var dateval = new Date(document.getElementById("to").value);
	var fromdateval = new Date(document.getElementById("from").value);
	dateval.setDate(dateval.getDate() + 1);
	var salaryDate = dateval.getFullYear() + '-' + (("0" + (dateval.getMonth() + 1)).slice(-2)) + '-' + (("0" + dateval.getDate()).slice(-2));
	if (isNaN(dateval.getFullYear()) || isNaN(fromdateval.getFullYear())){
		alert("Please select valid date range");
	}
	else if(!isPreview)
	{
		var isFormSubmission = confirm("Are you sure want to generate invoice on " + salaryDate);
		if (isFormSubmission == true) {
			document.getElementById("generate").value = true;
			document.getElementById("query_form").submit();
		}
	}
	else {
		document.getElementById('preview_billing').value = true;
		$('#query_form').submit();
	}
}

function invoiceAddRow(tableId, rowCount)
{
	var table = document.getElementById(tableId);
	var rowlength = table.rows.length;
	var lastRow = table.rows[rowlength - 1];
	var lastDatePicker = $('.date', lastRow);
	var $rowClone = $(lastRow).clone(true);
	$rowClone.find('input:text').val('');
	var g=1;
	$rowClone.find('td').each(function(){
		var el = $(this).find(':first-child');
		var id = el.attr('id') || null;
		if(id) {
			var index = parseInt(id.split('_').pop());
			id = id.split('_');
			id.splice(-1,1);
			var prefix = id.join('_') + '_';
			el.attr('id', prefix+(index + 1));
			el.attr('name', prefix+(index + 1));
			if(prefix == "item_type_")
			{
				el.attr('disabled', false);
			}
		}
	});/* working fine */

    if(tableId == "milestoneTable")
    {
	    var datePickerClone = $('.date', $rowClone);
		var datePickerCloneId = 'billdate_' + rowlength;

		datePickerClone.data( "datepicker",
			$.extend( true, {}, lastDatePicker.data("datepicker") )
		).attr('id', datePickerCloneId);

		datePickerClone.data('datepicker').input = datePickerClone;
		datePickerClone.data('datepicker').id = datePickerCloneId;
    }


	$(table).append($rowClone);
    if(tableId == "milestoneTable")
    {
      datePickerClone.datepicker();
    }
	document.getElementById(rowCount).value = rowlength;
	clearId = tableId == "milestoneTable" ? "milestone_id_"+rowlength : (tableId == "txnTable" ? "txn_id_"+rowlength : "item_id_"+rowlength ) ;
	document.getElementById(clearId).value = "";
	if(document.getElementById('item_index_' + rowlength) != null)
	{
		document.getElementById('item_index_' + rowlength).innerHTML = rowlength;
	}

	if(tableId == "invoiceTable")
	{
		document.getElementById("product_id_"+rowlength).value = "";
		document.getElementById("material_id_"+rowlength).value = "";
	}

}

function addAmount(fldId)
{
	var cloumnId = parseInt(fldId.split('_').pop());
	var rate = document.getElementById('rate_'+  cloumnId);
	var quantity = document.getElementById('quantity_'+  cloumnId);
	var exchangerate_amount = document.getElementById('exchangerate_amount_'+ cloumnId)
	if(rate.value != null && quantity.value != null)
	{
		document.getElementById("amount_"+  cloumnId).innerHTML = (rate.value * quantity.value * exchangerate_amount.value).toFixed(2);
		document.getElementById("original_amount_"+  cloumnId).innerHTML = (rate.value * quantity.value).toFixed(2);
	}
	var table = document.getElementById('invoiceTable');
	var len = table.rows.length;
	var total = 0;
	var count = 0;
	var tothash = new Object();
	var productTothash = new Object();
	for(var i = 1 ; i <= (len-1) ; i++)
	{
		if(document.getElementById("project_id_"+i) != null && document.getElementById("product_id_"+i).value == "" ) {
			var dropdown = document.getElementById("project_id_"+i);
			var ddvalue = dropdown.options[dropdown.selectedIndex].value;
			tothash[ddvalue] = (tothash[ddvalue] == null ? 0 : tothash[ddvalue]) + parseInt($("#amount_"+i).text());
		}
		if(document.getElementById("product_id_"+i).value != "")
		{
			productId = document.getElementById("product_id_"+i).value;
			productTothash[productId] = (productTothash[productId] == null ? 0 : productTothash[productId]) + parseInt($("#amount_"+i).text() );
		}
		total = total + parseInt($("#amount_"+i).text());

	}

	var taxtotal = 0;
	if(document.getElementById('taxTable') != null) {
		var taxTable = document.getElementById('taxTable');
		var taxlen = taxTable.rows.length;
		for(j=1 ;j < taxlen ; j++)
		{
			if(document.getElementById("tax_pjt_id"+j) != null) {
				pjtId = document.getElementById('tax_pjt_id'+j).value;
				var taxamount = 0;
				if(tothash.hasOwnProperty(pjtId))
				{
					taxamount = tothash[pjtId] * (parseFloat($("#taxrate"+j).text()/100));
				}
				taxtotal = taxtotal + taxamount;
				document.getElementById("taxamount"+ j).innerHTML = taxamount.toFixed(2);
			}
			if(document.getElementById("tax_product_id"+j) != null)
			{

				pId = document.getElementById("tax_product_id"+j).value;
				var taxamount = 0;
				if(productTothash.hasOwnProperty(pId))
				{
					taxamount = productTothash[pId] * (parseFloat($("#taxrate"+j).text()/100));
				}
				taxtotal = taxtotal + taxamount;
				document.getElementById("taxamount"+ j).innerHTML = taxamount.toFixed(2);
			}
		}
	}
	document.getElementById('invsubtotal').innerHTML = "SubTotal : " + total.toFixed(2);
	if(document.getElementById('invtotalamount') != null) {
		document.getElementById('invtotalamount').innerHTML = "Total : " + (taxtotal + total).toFixed(2);
	}
	var roundtotal = Math.round(taxtotal + total);
	if(document.getElementById('taxTable') != null) {
		var roundlen = document.getElementById('taxTable').rows.length;
		if(roundlen > 1)
		{
			document.getElementById('roundamount').innerHTML = (roundtotal - (taxtotal + total)).toFixed(2);
		}
	}
	document.getElementById('roundtotalamount').innerHTML = roundtotal.toFixed(2);
}

function deleteRow(tableId, totalrow)
{

	if(tableId == "txnTable")
	{
		var table = document.getElementById(tableId);
		var rowlength = table.rows.length;
		if(rowlength > 3)
		{
			document.getElementById(tableId).deleteRow(row_id);
			document.getElementById(totalrow).value = document.getElementById(totalrow).value - 1;
			for(i = 1; i < rowlength-1; i++)
			{
				var colCount = table.rows[i].cells.length;
				for(var j=0; j<colCount; j++)
				{
					var input = document.getElementById(tableId).rows[i].cells[j].getElementsByTagName("*")[0];
					input.id = table.rows[i].cells[j].headers + '_' + i;
					input.name = table.rows[i].cells[j].headers + '_' + i;
				}
			}
		}
		else{
			alert(deleteMsg);
		}
		updateAmount();
	}
	else{
		var table = document.getElementById(tableId);
		var rowlength = table.rows.length;
		document.getElementById(tableId).deleteRow(row_id);
		document.getElementById(totalrow).value = document.getElementById(totalrow).value - 1;
		for(i = 1; i < rowlength-1; i++)
			{
				var colCount = table.rows[i].cells.length;
				for(var j=0; j<colCount; j++)
				{
					var elements = document.getElementById(tableId).rows[i].cells[j].querySelectorAll("select, input, label");
					Array.from(elements).map(el => {
						if (el.type == 'hidden') {
							elID = el.id.split("_");
							elID[elID.length - 1] = i;
							elName = el.name.split("_");
							elName[elName.length - 1] = i;
							el.id = elID.join('_');
							el.name = elName.join('_');
						}
						else {
							el.id = table.rows[i].cells[j].headers + '_' + i;
							el.name = table.rows[i].cells[j].headers + '_' + i;
						}
					});
					$('#item_index_'+i).html(i)
				}
			}
	}
}

function openInvReportPopup(){
	var invId = document.getElementById('invoice_id').value;
	popupUrl = wkInvReportUrl + '&invoice_id=' + invId +'&is_report=true'
	window.open(popupUrl, '_blank', 'location=yes,scrollbars=yes,status=yes');
}

function tallyAmount(fldId)
{
	var fldval = document.getElementById(fldId).value;
	if(isNaN(fldval))
	{
		alert(fldval + " " + transValidMsg);
	}
	else{
		var addclm = parseInt(fldId.split('_').pop()) +1;
		var oldtable = document.getElementById("txnTable");
		var oldrowlength = oldtable.rows.length;
		if(addclm > 2 && addclm == oldrowlength )
		{
			invoiceAddRow('txnTable', 'txntotalrow');
		}
		updateAmount();
	}

}

function updateAmount()
{
	var isDebit = false;
	var debitAmount = 0;
	var creditAmount = 0;
	var totalamount = 0;
	var totDebit = 0;
	var totCredit = 0;
	var table = document.getElementById("txnTable");
	var rowlength = table.rows.length;
	for(var i = 1; i < rowlength; i++)
	{
		var txn_debit = document.getElementById('txn_debit_'+i);
		var txn_credit = document.getElementById('txn_credit_'+i);
		debval = txn_debit.value == "" ? 0 : parseFloat(txn_debit.value);
		crdtval = txn_credit.value == "" ? 0 : parseFloat(txn_credit.value);

		if( i != rowlength-1)
		{
			debitAmount += debval ;
			creditAmount += crdtval ;
		}
		if(txn_debit.value != "" && txn_credit.value == "" && i == 1)
		{
			isDebit = true;
		}
		var fieldId = (isDebit ? 'txn_credit_' :  'txn_debit_') + i;//(rowlength-1);
		if(i == (rowlength-1))
		{
			totalamount = isDebit ? debitAmount - creditAmount : creditAmount - debitAmount;
			totalamount = Math.abs(totalamount);
			var fieldId = ((isDebit && debitAmount > creditAmount) ? 'txn_credit_' :  ((!isDebit && debitAmount > creditAmount) ? 'txn_credit_' : 'txn_debit_')) + i;
			document.getElementById(fieldId).value = totalamount;
		}
		totDebit += txn_debit.value == "" ? 0 : parseFloat(txn_debit.value);
		totCredit +=  txn_credit.value == "" ? 0 : parseFloat(txn_credit.value);
		document.getElementById('debitTotal').innerHTML = totDebit;
		document.getElementById('creditTotal').innerHTML = totCredit;
	}
}

function txnAddrowValidation(tableId)
{
	var table = document.getElementById(tableId);
	var rowlength = table.rows.length;
	var isAddrow = false;
	for(var i = 1; i < 3; i++)
	{
		var txn_debit = document.getElementById('txn_debit_'+i);
		var txn_credit = document.getElementById('txn_credit_'+i);
		if(txn_debit.value != "")
		{
			isAddrow = true;
		}
	}
	if(rowlength > 2 && isAddrow)
	{
		invoiceAddRow('txnTable', 'txntotalrow');
	}
	else {
		alert(rowValidationMsg);
	}
}


function txnformValidation()
{
	var ret = true;
	var table = document.getElementById("txnTable");
	var rowlength = table.rows.length;
	var errormsg = "";
	if(rowlength < 2)
	{
		errormsg = rowValidationMsg;
		ret = false;
	}
	var dbval = document.getElementById('debitTotal').innerText;
	var crval = document.getElementById('creditTotal').innerText;
	if(parseFloat(dbval) != parseFloat(crval))
	{
		errormsg = dbcrvalidMsg;
		ret = false;
	}
	if(!ret)
	{
		alert(errormsg);
	}
	return ret;
}

function submitNewInvoiceForm(isAccBilling)
{
	var valid=true;
	var msg = '';
	var accDropdown = document.getElementById("related_parent");
	var pjtDropdown = document.getElementById("project_id");
	if(accDropdown.value=="")
	{
		valid=false;
		msg = msg + "Please select the Name.";
	}
	else if(pjtDropdown.value=="" && !isAccBilling) {
		valid=false;
		msg = msg + "Please select the project.";
	}
	if(!valid)
	{
		alert(msg);
	}
	return valid;

}

function paymentItemTotal(tableId, elementId, totFld)
{
	var table = document.getElementById(tableId);
	var rowlength = table.rows.length;
	var amount = 0;
	for(var i = 1; i < rowlength-1; i++)
	{
		fldId = elementId+i;
		fldAmount = document.getElementById(fldId);
		if(fldAmount.value != "")
		{
			if(isNaN(fldAmount.value))
			{
				alert("Please enter the valid amount");
				fldAmount.value = fldAmount.defaultValue
				amount = amount +  parseInt(fldAmount.value);

			} else {
				if(fldAmount.value < 0 )
				{
					alert("Please enter the valid amount");
					fldAmount.value = fldAmount.defaultValue;
					amount = amount +  parseInt(fldAmount.value);
				}
				else{
					amount = amount +  parseInt(fldAmount.value);
				}
			}

		}
	}
	document.getElementById(totFld).innerHTML = amount;
	document.getElementById('tot_pay_amount').value = amount;
}

function submitPaymentItemForm()
{
	ret = true;
	$('textarea').removeData('changed');
	fldAmount =document.getElementById('tot_pay_amount');
	if(fldAmount != null)
	{
		if(fldAmount.value == 0 )
		{
			ret = false;
			alert("Amount should be greater then zero");
		}
	}

	return ret;
}

function hideProductType()
{
	var productTypeDD = document.getElementById('product_type');
	if(productTypeDD != null)
	{
		productType = productTypeDD.value;
		if(productType == 'I' )
		{
			document.getElementById("lbl_depreciation").style.display = 'none';
			document.getElementById("depreciation_rate").style.display = 'none';
			document.getElementById("per_annum").style.display = 'none';
		}
		else
		{
			document.getElementById("lbl_depreciation").style.display = 'block';
			document.getElementById("depreciation_rate").style.display = 'block';
			document.getElementById("per_annum").style.display = 'block';
		}
	}

}

function showWinningNote()
{
	if(document.getElementById('quote_won').checked)
	{
		document.getElementById("lbl_winning_note").style.display = 'block';
		document.getElementById("winning_note").style.display = 'block';
	} else {
		document.getElementById("lbl_winning_note").style.display = 'none';
		document.getElementById("winning_note").style.display = 'none';
	}
}
$().ready(function(){
	setDescription(false);
	$("[id^=amount]").change(function(){
		setDescription(true);
	});
});
function setDescription(isonload){
	if(isonload){
		$("#description").val("");
	}
	if($("#description").val() == "" || isonload){
		$("[id^=amount]").each(function(){
			var oldDesc = $("#description").val();
			var amount = this.value;
			if(amount > 0){
				var accName = $("#related_parent :selected").text();
				var index = (this.name).replace("amount","");
				var invoiceNo = $("#invoice_no" + index).val();
				var org_currency = $("#invoice_org_currency" + index).val();
				var desc = "AccName:" + accName + " InvNo:#" + invoiceNo + " PaymentAmt:" + org_currency + amount;
				if(oldDesc != ""){
					desc = oldDesc + "\n"+ desc;
				}
				$("#description").val(desc);
			}
		});
	}
}

function showQuantityDetails(invItemId) {
	var url = "/wkinvoice/getQuantityDetails";
	var data = {inv_item_id: invItemId}
	getTimeDetails(url, data)
}

function showUnbillQtyDetails(project_id, issue_id, start_date, end_date, parent_id, parent_type) {
	var url = "/wkinvoice/getUnbilledQtyDetails";
	var data = {project_id: project_id, start_date: start_date, end_date: end_date, parent_id: parent_id, parent_type: parent_type, issue_id: issue_id}
	getTimeDetails(url, data)
}

function getTimeDetails(url, data){
	var oldProjID = ''
	var tableEntries = ''
	$.ajax({
		url: url,
		data: data,
	 	success: function(result){
			$.each( result, function( i, l ){
				tableEntries += formQuantityTable(i, l, oldProjID);
				oldProjID = l.projID
			});
			if (tableEntries && tableEntries.length > 0){
				$(" #qunatityTable").html(tableEntries);
			}
			else{
				$(" #qunatityTable").html('<p style="clear:both" class="nodata">'+label_no_data+'</p>');
			}
		$("#quantity-dlg").dialog({ title: 'Quantity', width: '80%', height: $(window).height(),});
	}});
}

function formQuantityTable(i, l, oldProjID) {
	var projName = ''
	var styleTD = 'class=lbl-txt-align style=width:330px;'
	 var tableHeaders = (i > 0) ? '' :  "<tr class=quantityHeaters><th "+styleTD+"> Project </th><th "+styleTD+"> Issue </th><th "+styleTD+"> User </th><th "+styleTD+"> Date </th><th "+styleTD+"> Hours </th></tr>"
	if(l.projID != oldProjID){ projName = l.proj_name }
	var tableDetails = tableHeaders + "<tr class=quantityDetails><td "+styleTD+">"+ projName +"</td></tr><tr class=quantityDetails><td></td><td "+styleTD+">" + l.subject + "</td><td "+styleTD+">" + l.usr_name + "</td><td "+styleTD+">" + l.spent_on + "</td><td "+styleTD+">" + l.hours + "</td></tr>";
	return tableDetails
}

function selectEntryPopup() {
	var url = "/wkinvoice/generateTimeEntries";
	var dateval = new Date(document.getElementById("to").value);
	var fromdateval = new Date(document.getElementById("from").value);
	toDate = dateval.getFullYear() + '-' + (("0" + (dateval.getMonth() + 1)).slice(-2)) + '-' + (("0" + dateval.getDate()).slice(-2));
	fromDate = fromdateval.getFullYear() + '-' + (("0" + (fromdateval.getMonth() + 1)).slice(-2)) + '-' + (("0" + fromdateval.getDate()).slice(-2));
	var accID = $('#account_id').val()
	var contactID = $('#contact_id').val()
	var filter = $('input[name="polymorphic_filter"]:checked').val();
	var projectID = $('#project_id').val()
	var data = {dateval: toDate, fromDate: fromDate, accID: accID, contactID: contactID, projectID: projectID, filter_type: filter}
	if(isNaN(dateval.getFullYear()) || isNaN(fromdateval.getFullYear())){
		alert("Please select valid date range");
	}
	else{
		getSelectEntry(url, data)
	}
}

function getSelectEntry(url, data){
	$.ajax({
		url: url,
		data: data,
	 	success: function(resData){
			if(resData.length > 0){
				const preHeader = (type="") =>{
					return "<th><input type='checkbox' name='checkall_"+type+"' value='1' id='checkall_"+type+"' checked onclick='handleCheckAll(this,\""+type+"\");'></th>";
				}
				const preList = (type="", el={}) =>{
					const id = (el.id || "").toString();
					delete el["id"];
					return "<td><input type='checkbox' name='check_"+type+"' value='"+id+"' class='check_"+type+"' checked onclick='handleCheck(\""+type+"\");'></td>";
				}
				resData.map((data, i) =>{
					const fixedCast = data.type != "wk_billing_schedules";
					renderData(data, {clear: (i == 0), type: data.type, preHeader:  fixedCast && preHeader, preList: fixedCast && preList, title: data.title});
				});
			}else{
				renderData([]);
			}
			$("#dialog").dialog({
				modal: true,
				title: title,
				width: "80%",
				height: $(window).height(),
				buttons: {
					"Generate": function() {
						invoiceFormSubmission(false)
					},
					"Cancel": function() {
						$(this).dialog("close");
					}
				}
			});
		},
		beforeSend: function(){ $(this).addClass("ajax-loading"); },
		complete: function(){ $(this).removeClass("ajax-loading"); }
	});
}

function handleCheckAll(ele, type){
	$(".check_"+type).prop("checked", $(ele).is(":checked"));
}

function handleCheck(type){
	$("#checkall_"+type).prop("checked", $(".check_"+type+":checked").length == $(".check_"+type).length);
}

function InvCompDialog(action, listId)
{
	$( "#invcomp-dlg" ).dialog({ title: lblInvComp});
	listboxId = listId;
	var listbox = document.getElementById(listboxId);
	var invCompName = document.getElementById("inv_copm_name");
	var invCompVal = document.getElementById("inv_copm_value");
	if('Add' == action)
	{
		leaveAction = action;
		invCompName.value = "";
		invCompVal.value = "";
		$( "#invcomp-dlg" ).dialog( "open" )
	}
	else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0)
	{
		var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
		invCompName.value = !listboxArr[1] ? "" : listboxArr[1];
		invCompVal.value = !listboxArr[2] ? "" : listboxArr[2];
		leaveAction = action;
		compId = listboxArr[0];
		$( "#invcomp-dlg" ).dialog( "open" )
	}
	else if(listbox != null && listbox.options.length >0)
	{
		alert(selectListAlertMsg);
	}
}
