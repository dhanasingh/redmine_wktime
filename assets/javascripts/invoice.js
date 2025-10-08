var row_id = 0;
var compId = 0;
var table = null;
var rowlength = null;
var lastRow = null;
var lastDatePicker = null;
var $rowClone = null;

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

	setDescription(false);
	$("[id^=amount]").change(function(){
		setDescription(true);
	});

	//Load New Row
	table = document.getElementById('deliveryTable');
	if(table != null){
		rowlength = table.rows.length - 1 ;
		lastRow = table.rows[rowlength];
		$rowClone = $(lastRow).clone(true);
		$rowClone.find('td').each(function(){
			var el = $(this).find(':first-child');
			var id = el.attr('id') || null;
			if(id) {
				var index = parseInt(id.split('_').pop());
				id = id.split('_');
				id.splice(-1,1);
				var prefix = id.join('_') + '_';
				el.attr('id', prefix+(index));
				el.attr('name', prefix+(index));
			}
		});
	}

	// for searchable dopdown
	if($("#invoiceTable .productItemsDD").length > 0){
		$("#invoiceTable .productItemsDD").select2();

		if(["I", "SQ"].includes($('#invoice_type').val())){
			//Show Product Items for material & Asset invoice only
			$("#invoiceTable .productItemsDD").each(function(){
				showHideProductItem(this);
			});
			$("#invoiceTable .item_types").change(function(){
				showHideProductItem(this);
				invItemChange(this);
			});
		}
		else{
			$("[id^='serial_number_img_']").hide();
		}

		$(".productItemsDD").change(function(){
			let row = parseInt((this.name).split('_').pop());
			let text = $("#invoice_item_id_"+row).val() != "" ? $("#invoice_item_id_"+row+ " option:selected").text() : "";
			$("#invoiceTable #name_"+row).val(text);
		});

			//Apply tax rows
		if(["SI", "I", "SQ"].includes($('#invoice_type').val())){
			let searchParams = new URLSearchParams(window.location.search);
				if(!(searchParams.has("invoice_id") && searchParams.get("invoice_id") > 0)){
				let productIDs = [];
				$(".productItemsDD").each(function(){
					let id = (this.value).split(",").shift();
					if(!productIDs.includes(id)){
						productIDs.push(id);
						applyTax(this, "invoice_item");
					}
				});

				let projectIDs = [];
				$("[id^='project_id_']").each(function(){
					if(!projectIDs.includes(this.value)){
						projectIDs.push(this.value);
						applyTax(this, "project");
					}
				});
			}

			$(".productItemsDD").change(function(){
				let row = parseInt((this.name).split('_').pop());
				let text = ["", '0'].includes($("#invoice_item_id_"+row).val()) ? "" : $("#invoice_item_id_"+row+ " option:selected").text();
				$("#invoiceTable #name_"+row).val(text);

				var itemType = $("#invoiceTable #item_type_"+row).val();
				if ((["m", "a"].includes(itemType) && ["I"].includes($('#invoice_type').val())) || ["SI"].includes($('#invoice_type').val())){
					applyTax(this, "invoice_item");
				}
				if(["I", "SQ"].includes($('#invoice_type').val())){
					fillInvFields(row);
				}
			});

			$("[id^='project_id_']").change(function(){
				//load itemDD
				url = "/"+controller_name+"/get_issue_dd";
				data = {project_id: $(this).val() };
				let row = parseInt((this.name).split('_').pop());
				changeDD = document.getElementById("invoice_item_id_"+row);
				$.ajax({
					url: url,
					data: data,
					success: function(resData){
						updateUserDD(resData, changeDD, 1, true, false, label_prod_item);
						$("#invoice_item_id_"+row).val(null).trigger('change');
						$("#name_"+row).val('');
					},
					beforeSend: function(){ $(this).addClass("ajax-loading"); },
					complete: function(){ $(this).removeClass("ajax-loading"); }
				});
				applyTax(this, "project");
			});

			//Updating Tax rows
			$(".item_types").change(function(){
				if(["i", "e"].includes(this.value)){
					let row = parseInt((this.name).split('_').pop());
					applyTax(document.getElementById("project_id_"+row), "project");
					$("#invoice_item_id_"+row).val("");
				}
				removeTaxRows();
			})
		}
	}
});

function invoiceFormSubmission(isPreview)
{
	var timeentryIDs = $('input[name=check_time_entries]:checked').map(function(){
 		return $(this).val();
  }).get();
	var materialentryIDs = $('input[name=check_wk_material_entries]:checked').map(function(){
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

function invoiceAddRow(tableId, rowCount){
	if(!$("#deliveryTable").length || ($("#"+rowCount).val() >= 1)){
		table = document.getElementById(tableId);
		rowlength = table.rows.length;
		let skipRows = tableId == "invoiceTable" ? 2 : 1;
		lastRow = table.rows[rowlength - skipRows];
		lastDatePicker = $(".date", lastRow);
		let removedSelect2 = false
		if(tableId == "invoiceTable" && $("#invoice_item_id_"+(rowlength-skipRows)).data("select2")){
			removedSelect2 = true
			$("#invoice_item_id_"+(rowlength-skipRows)).select2("destroy");
		}
		$rowClone = $(lastRow).clone(true);
		if(removedSelect2) $("#invoice_item_id_"+(rowlength-skipRows)).select2();
		$rowClone.find("input:text").val("");
		$rowClone.find("td").each(function(){
			$(this).children().each(function(){
				const dd = $(this).find('select');
				const parent = $(dd).parent('div');
				if(dd.length > 0 && parent.length > 0){
					ele = dd;
					$(parent).before(dd);
					$(parent).remove();
				}else{
					ele = this;
				}
				var id = $(ele).attr("id") || null;
				if(id) {
					var index = parseInt(id.split("_").pop());
					id = id.split("_");
					id.splice(-1,1);
					var prefix = id.join("_") + "_";
					$(ele).attr("id", prefix+(index + 1));
					$(ele).attr("name", prefix+(index + 1));
					if(prefix == "item_type_" || tableId == "deliveryTable") {
						$(ele).attr("disabled", false);
					}
				}
			});
		});
	}

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
	if(tableId == "milestoneTable"){
		datePickerClone.datepicker();
	}
	if(tableId == 'invoiceTable') rowlength -= 1
	document.getElementById(rowCount).value = rowlength;

	// Update Item Index label
	updateIndexLabel(rowlength);

	clearId = tableId == "milestoneTable" ? "milestone_id_"+(rowlength) : (tableId == "txnTable" ? "txn_id_"+(rowlength) : "item_id_"+(rowlength) ) ;
	$("#"+clearId).val("");
	if(tableId == "invoiceTable"){
		if(["I", "SQ"].includes($('#invoice_type').val())){
			$("#item_type_"+(rowlength)).val("i");
			$("#invoice_item_id_"+(rowlength)).val("").select2();
			applyTax(document.getElementById("project_id_"+(rowlength)), "project");
		}else{
			$("#invoice_item_id_"+(rowlength)).val("").select2();
		}
		$("#product_id_"+(rowlength)).val("");
		$("#material_id_"+(rowlength)).val("");
		$("#original_amount_"+(rowlength)).html("0.00");
		$("#amount_"+(rowlength)).html("0.00");
	}
	if(tableId == "shipmentTable"){
		$("#invoice_item_id_"+(rowlength)).val("");
	}

	// For Load invoice type dropdown
	if (["I", "SQ"].includes($('#invoice_type').val())){
		let changeDD = document.getElementById("invoice_item_id_"+rowlength);
		$.ajax({
			url:  "/"+controller_name+"/get_issue_dd",
			data: {project_id: $("#invoiceTable #project_id_"+rowlength).val() },
			success: function(resData){
				updateUserDD(resData, changeDD, 1, true, false, label_prod_item);
			}
		});
	}
}

function updateIndexLabel(rowlength){
	if($("#item_index_" + (rowlength)).length > 0){
		$("#item_index_" + (rowlength)).html(rowlength);
	}
}

function addAmount(fldId){
	//Update Orginal amount & Amount
	let row = parseInt(fldId.split('_').pop());
	let rate = parseFloat($("#rate_"+row).val() || 0);
	let quantity = parseFloat($("#quantity_"+row).val() || 0);
	let exRate = parseFloat($("#exchangerate_amount_"+row).val());
	$("#original_amount_"+row).html((rate * quantity).toFixed(2));
	$("#amount_"+row).html((rate * quantity * exRate).toFixed(2));
	updateTotals();
}

function updateTotals(){
	updateTaxAmounts();
	//Updating Sub total
	let orgAmountSubTotal = 0;
	let amountSubTotal = 0;
	$("[id^='original_amount_']").each(function(){
		orgAmountSubTotal += parseFloat($(this).text() || 0);
	});
	$("[id^='amount_']").each(function(){
		amountSubTotal += parseFloat($(this).text() || 0);
	});
	$("#subtotal_org_amount").html(orgAmountSubTotal.toFixed(2));
	$("#subtotal_amount").html(amountSubTotal.toFixed(2));

	//Updating Tax Total
	let orgTotalTax = orgAmountSubTotal || 0;
	let totalTax = amountSubTotal || 0;
	$("[id^='org_taxamount_']").each(function(){
		orgTotalTax += parseFloat($(this).text() || 0);
	});
	$("[id^='taxamount_']").each(function(){
		totalTax += parseFloat($(this).text() || 0);
	});
	orgTotalTax = orgTotalTax.toFixed(2);
	totalTax = totalTax.toFixed(2);
	$("#org_total_tax").html(orgTotalTax);
	$("#total_tax").html(totalTax);
	orgTotalTax = parseFloat(orgTotalTax);
	totalTax = parseFloat(totalTax);

	//Calculate & Updating Round off Amount
	let totRoundOrgAmt = 0;
	let totRoundAmt = 0;
	$(".round_tr").each(function(){
		let roundOrgAmt = (Math.round(orgTotalTax) - orgTotalTax).toFixed(2);
		let roundAmt = (Math.round(totalTax) - totalTax).toFixed(2);
		totRoundOrgAmt += parseFloat(roundOrgAmt);
		totRoundAmt += parseFloat(roundAmt);
		$("#round_org_amount").html(roundOrgAmt);
		$("#round_amount").html(roundAmt);
	});

	//Updating grand total
	let totalOrgAmount = orgTotalTax + totRoundOrgAmt;
	let totalAmount = totalTax + totRoundAmt;
	$("#inv_orginal_total").html(totalOrgAmount.toFixed(2));
	$("#inv_total").html(totalAmount.toFixed(2));
}

function updateTaxAmounts(){
	let totals = {};
	["project", "invoice_item"].map((type)=>{
		totals[type] = getTaxamounts(type);
		setTaxAmounts(totals[type], type);
	});
}

function getTaxamounts(type){
	let items = {};
	$("[id^='"+type+"_id_']").each(function(){
		let row = parseInt((this.name).split('_').pop());
		let id = (this.value).split(",").shift();
		if(id && (type == "invoice_item" || ["i", "e"].includes($("#item_type_"+row).val()))){
			$("[id^='tax_"+type+"_id_']").each(function(){
				if(this.value && this.value == id){
					let index = parseInt((this.name).split('_').pop());
					items[this.value+"_"+index] = items[this.value+"_"+index] || {};
					let exchangeRate = parseFloat($("#exchangerate_amount_"+row).val() || 0);
					let rate = parseFloat($("#tax_rate_"+index).val() || 0);
					let orginalAmount = (parseFloat($("#rate_"+row).val() || 0) * (parseFloat($("#quantity_"+row).val()) || 0) * (rate/100)).toFixed(2);
					let amount = (parseFloat(orginalAmount) * exchangeRate).toFixed(2);
					items[this.value+"_"+index]['orgAmount'] = (items[this.value+"_"+index]['orgAmount'] || 0) + parseFloat(orginalAmount);
					items[this.value+"_"+index]['amount'] = (items[this.value+"_"+index]['amount'] || 0) + parseFloat(amount);
				}
			});
		}
	});
	return items;
}

function setTaxAmounts(totals, type){
	$("[id^='tax_"+type+"_id_']").each(function(){
		if(this.value){
			let index = parseInt((this.name).split('_').pop());
			totals[this.value+"_"+index] = totals[this.value+"_"+index] || {};
			$("#org_taxamount_"+index).html((totals[this.value+"_"+index]['orgAmount'] || 0).toFixed(2));
			$("#taxamount_"+index).html((totals[this.value+"_"+index]['amount'] || 0).toFixed(2));
		}
	});
}

function deleteRow(tableId, totalrow){
	if(tableId == "txnTable"){
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
		//Add row if table has only a row
		if((tableId == "invoiceTable" && $("#"+tableId +" tr").length == 3) || $("#"+tableId +" tr").length == 2){
			invoiceAddRow(tableId, totalrow);
		}

		var table = document.getElementById(tableId);
		var rowlength = tableId == "invoiceTable" ? table.rows.length - 2 : table.rows.length;
		document.getElementById(tableId).deleteRow(row_id);
		document.getElementById(totalrow).value = document.getElementById(totalrow).value - 1;

		$("#"+tableId +" > tbody > tr").each(function(index){
			if((index+1) >= row_id && (index+1) < rowlength){
				$(this).find('td').each(function(){
					$(this).children().each(function(){
						var id = $(this).attr('id') || null;
						if(id) {
							id = id.split('_');
							id.splice(-1,1);
							var prefix = id.join('_') + '_';
							$(this).attr('id', prefix+(index + 1));
							$(this).attr('name', prefix+(index + 1));
						}
					});
				});
			}

			// Update Item Index label
			updateIndexLabel(index + 1);
		});
		if(tableId == 'shipmentTable'){
			var availabel_inv_ids = $('[id^=item_id]').map(function(){
				return $(this).val();
			}).get();
			$('#availabelInvIds').val(availabel_inv_ids)
		}

		removeTaxRows();
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

function updateAmount(){
	var isDebit = false;
	var debitAmount = 0;
	var creditAmount = 0;
	var totalamount = 0;
	var totDebit = 0;
	var totCredit = 0;
	var table = document.getElementById("txnTable");
	var rowlength = table.rows.length;
	for(var i = 1; i < rowlength; i++){
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

function showQuantityDetails(invItemId, itemType) {
	var url = "/wkinvoice/get_quantity_details";
	var data = {inv_item_id: invItemId, itemType}
	getSpentDetails(url, data)
}

function showUnbillQtyDetails(project_id, issue_id, start_date, end_date, parent_id, parent_type, itemType) {
	var url = "/wkinvoice/get_unbilled_qty_details";
	var data = {project_id, start_date, end_date, parent_id, parent_type, issue_id, itemType}
	getSpentDetails(url, data)
}

function getSpentDetails(url, data){
	$.ajax({
		url: url,
		data: data,
	 	success: function(resData){
			renderData(resData);
			$("#dialog" ).dialog({
				modal: true,
				title: resData.title,
				width: "80%",
				height: window.innerHeight - 100
			});
		}
	});
}


function selectEntryPopup() {
	var url = "/wkinvoice/generate_time_entries";
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

function showHideProductItem(ele){
	let row = parseInt((ele.name).split('_').pop());
	if ($("#invoiceTable #item_type_"+row).val() != 'm'){
		$("#serial_number_img_"+row).hide();
	}
	if($("#invoice_item_id_"+row).data('select2')) $("#invoice_item_id_"+row).select2('destroy');
	if(!['m', 'a', 'i', 'e'].includes($("#invoiceTable #item_type_"+row).val())){
		$("#invoice_item_id_"+row).hide();
		$("#invoice_item_id_"+row).val("");
	}else{
		$("#invoice_item_id_"+row).show();
		$("#invoice_item_id_"+row).select2();
	}
}

function applyTax(ele, type){
	let checkTaxRow = false;
	let ids = ($(ele).val() || "").split(",");
	let id = ids[0];
	$("[id^='tax_"+type+"_id_']").each(function(){
		let row = parseInt((this.name).split('_').pop());
		if(this.value == id && (type == "invoice_item" || !$("#tax_invoice_item_id_"+row).val())) checkTaxRow = true;
	});

	removeTaxRows();
	if(id && !checkTaxRow){
		let url = "/wkorderentity/";
		let data = {}
		if(type == "invoice_item"){
			url += "get_product_tax";
			data = {item_id: ids[1], invoice_type: $('#invoice_type').val() }
		}else{
			url += "get_project_tax";
			data = {project_id: id, parent_type: $("#parent_type").val(), parent_id: $("#parent_id").val()}
		}

		//Get Tax data
		$.ajax({
			url: url,
			data: data,
			success: function(resData){
				if(resData.length > 0) renderTaxRows(resData, ele);
			},
			beforeSend: function(){ $(this).addClass("ajax-loading"); },
			complete: function(){ $(this).removeClass("ajax-loading"); }
		});
	}else{
		updateTotals();
	}
}

function removeTaxRows(){
	//Remving Proj tax rows
	let projIDs = [];
	$("[id^='project_id_']").each(function(){
		let row = parseInt((this.name).split('_').pop());
		if(["i", "e"].includes($("#item_type_"+row).val()) && !projIDs.includes(this.value)) projIDs.push(this.value);
	});

	$("[id^='tax_project_id_']").each(function(){
		let row = parseInt((this.name).split('_').pop());
		if(this.value && !projIDs.includes(this.value) && !$("#tax_invoice_item_id_"+row).val()){
			$(this).parents("tr").remove();
	}
	});
	//Remving product tax rows
	let prodIDs = [];
	$(".productItemsDD").each(function(){
		let id = (this.value || '').split(',').shift() || null;
		let row = parseInt((this.name || '').split('_').pop());
		let projectID = $("#project_id_"+row).val();
		if($('#invoice_type').val() == "SI" || ["m", "a"].includes($("#item_type_"+row).val()) && id && !prodIDs.includes(id)){
			prodIDs.push(id);
		}
	});
	$("[id^='tax_invoice_item_id_']").each(function(){
		if(this.value && !prodIDs.includes(this.value)){
			 $(this).parents("tr").remove();}
	});
	updateTotals();
}

function renderTaxRows(data, ele){
	let row = parseInt((ele.name).split('_').pop());
	let exchangeRate = parseFloat($("#exchangerate_amount_"+row).val() || 0);
	let currency = $("#currency_"+row).val() || "";
	let orginalCurrency = $("#original_currency_"+row).val() || "";
	let orginalAmount = (($("#rate_"+row).val() || 0) * (parseFloat($("#quantity_"+row).val()) || 0)).toFixed(2);
	orginalAmount = parseFloat(orginalAmount);
	let amount = (orginalAmount * exchangeRate).toFixed(2);
	amount = parseFloat(amount);
	data.map((item=> {
		item["org_amount"] =  ((item.rate/100) * orginalAmount).toFixed(2);
		item["amount"] = ((item.rate/100) * amount).toFixed(2);
		item["type"] = label_tax;
		item["org_currency"] = orginalCurrency;
		item["currency"] = currency;
	}));
	let rowIndex = $('#taxTable tr').length - 1;
	let invoiceType = $('#invoice_type').val();
	let tr = '';
	data.map((item, index) =>{
		index += rowIndex +1;
		tr += '<tr>';
		tr += '<td style="width: 5%"></td>';
		//Project
		tr += '<td style="width:'+(invoiceType == 'I' ? '10%' : '0%')+'">'+(item.project || "");
		tr += '<input type="hidden" name="tax_project_id_'+index+'" id="tax_project_id_'+index+'" value="'+(item.project_id || "")+'"></td>';
		//Product item
		tr += '<td style="width: 20%; text-align: center;">'+(item.product || "");
		tr += '<input type="hidden" name="tax_invoice_item_id_'+index+'" id="tax_invoice_item_id_'+index+'" value="'+(item.product_id || "")+'"></td>';

		tr += '<td style="width: 20%; text-align: center;">'+item.name+'</td>';
		tr += '<td style="width: 5%; text-align: center;">'+item.type+'</td>';
		tr += '<td style="width:11%; text-align: center;">'+(item.rate).toFixed(2)+' % <input type="hidden" name="tax_rate_'+index+'" id="tax_rate_'+index+'" value="'+item.rate+'"></td>';
		tr += '<td style="width: 11%"></td>';
		tr += '<td style="width: 7%; text-align: right;">'+item.org_currency+' <label id="org_taxamount_'+index+'">'+(item.org_amount || "0.00")+'</label></td>';
		tr += '<td style="width: 7%; text-align: right;">'+item.currency+' <label id="taxamount_'+index+'">'+(item.amount || "0.00")+'</label></td>';
		tr += '<td style="width: 5%"></td>';
		tr += '</tr>';
	});
	$("#taxTable").find("tr:last").before(tr);
	updateTotals();
}

function invItemChange(ele){
	let row = parseInt((ele.name).split('_').pop());
	changeDD = document.getElementById("invoice_item_id_"+row);
	var itemType = $("#invoiceTable #item_type_"+row).val();
	var additional_item_type = $('#additional_item_type').val()
	if(['m'].includes(itemType)){
	 $("#serial_number_img_"+row).show();
	}else{
		$("#serial_number_img_"+row).hide();
	}
	switch(itemType){
		case 'm':
			$("#invoiceTable #invoice_item_type_"+row).val('WkInventoryItem');
			url = "/wklogmaterial/modify_product_dd";
			data = {ptype: 'product_item', log_type: 'I', module_type: 'invoice'};
			break;
		case 'a':
			$("#invoiceTable #invoice_item_type_"+row).val('WkInventoryItem');
			url = "/wklogmaterial/modify_product_dd";
			data = {ptype: 'product_item', log_type: 'A', module_type: 'invoice'};
			break;
		default:
			$("#invoiceTable #invoice_item_type_"+row).val('Issue');
			url = "/"+controller_name+"/get_issue_dd";
			data = {project_id: $("#invoiceTable #project_id_"+row).val() };
	}

	$.ajax({
		url: url,
		data: data,
		success: function(resData){
			if(additional_item_type && itemType =='a'){
				$.ajax({
					url: "/wklogmaterial/modify_product_dd",
					data: {ptype: 'product_item', log_type: additional_item_type, module_type: 'invoice'},
					success: function(resData1){
						resData = resData+resData1
						updateUserDD(resData, changeDD, 1, true, false, label_prod_item);
					}
				});
			}
			else{
				updateUserDD(resData, changeDD, 1, true, false, label_prod_item);
			}
			$("#invoice_item_id_"+row).val(null).trigger('change');
			$("#name_"+row).val('');
		},
		beforeSend: function(){ $(this).addClass("ajax-loading"); },
		complete: function(){ $(this).removeClass("ajax-loading"); }
	});
}

function fillInvFields(row){
	var invoice_item_id = $("#invoice_item_id_"+row).val();
	var itemType = $("#invoiceTable #item_type_"+row).val();
	var inventory_id = invoice_item_id && invoice_item_id.split(',').pop();
	var project_id = $("#invoiceTable #project_id_"+row).val();
	var invoice_type = $("#invoice_type").val();
	var data = {};
	url = "/wkorderentity/get_inv_detals";
	data = {item_id: inventory_id, itemType: itemType, invoice_type: invoice_type, project_id: project_id};
	$.ajax({
		url: url,
		data: data,
		success: function(resData){
			if (Object.keys(resData).length > 0){
				var rate = resData['rate'] || ''
				var qty = resData['quantity'] || ''
				var sn = resData['serial_number'] || ''
				var running_sn = resData['running_sn'] || ''
				if(rate){
					$("#product_serial_no_"+row).val([sn,running_sn,qty]);
					$("#rate_"+row).val(rate);
					$("#quantity_"+row).val(qty);
					addAmount('rate_'+row)
				}
			}
			if (Object.keys(resData).length == 0){
				$("#rate_"+row).val('');
				$("#quantity_"+row).val('');
			}
		},
		beforeSend: function(){ $(this).addClass("ajax-loading"); },
		complete: function(){ $(this).removeClass("ajax-loading"); }
	});
}

function saveEntity(){
	var ret = true;
	var invoice_item_id = '';
	var qty = {};
	$("#invoiceTable [id^='quantity_']").each(function(){
		let row = parseInt((this.name).split('_').pop());
		if(['m', 'a'].includes($("#invoiceTable #item_type_"+row).val())){
			invoice_item_id = $("#invoice_item_id_"+row).val();
			var inv_id = invoice_item_id && invoice_item_id.split(',').pop().trim()
			qty[inv_id] = qty[inv_id] || 0
			qty[inv_id] += parseFloat($("#quantity_"+row).val()) || 0;
		}
	});
	keys = Object.keys(qty)
	url = "/wkorderentity/check_qty";
	data = {inventory_itemID: keys }
	$.ajax({
		url: url,
		data: data,
		async: false,
		success: function(resData){
			var errMsg = [];
			$.each(qty, function(key, val){
				if(resData[parseInt(key)]['item']['available_quantity'] < val){
					errMsg.push(resData[parseInt(key)]['name']);
				}
			});
			if(errMsg.length > 0){
				var confirmMsg = confirm(errMsg+' Quantity is higher than avilable quantity')
				if(confirmMsg){ret = true;}
				else{ret = false;}
			}
		},
		beforeSend: function(){ $(this).addClass("ajax-loading"); },
		complete: function(){ $(this).removeClass("ajax-loading"); }
	});
	return ret;
}

function getUsedSerialNumber(ele){
	var row = parseInt((ele.id).split('_').pop());
	$("#inv_serial_no").val('')
	$("#inv_serial_no").val($("#used_serial_no_"+row).val());
	$("#item_serial_no").val($("#product_serial_no_"+row).val());
	var sn = [];
	$("#serialno-dlg").dialog({
		modal: true,
		title: 'Serial Number',
		width: "30%",
		buttons: {
			"Ok": function() {
				$("#used_serial_no_"+row).val($("#inv_serial_no").val());
				if($('#inv_serial_no').val()){
					($('#inv_serial_no').val().split(',')).map(function(number){ sn.push({id:'', serial_number: number})});
				}
				$("#used_serialNo_obj_"+row).val(JSON.stringify(sn));
				$(this).dialog("close");
			},
			Cancel: function() {
				$(this).dialog("close");
			}
		}
	});
}

function deleteAllRows(tableId, totalrow){
	let isDelete = confirm(delete_all_row);
	if(isDelete){
		let table = document.getElementById(tableId);
		let rowlength = tableId == "invoiceTable" ? table.rows.length - 2 : table.rows.length;
		for (var i = 1; i <= rowlength; i++) {
			row_id = table.rows.length - 2;
			deleteRow(tableId, totalrow);
		}
	}
}