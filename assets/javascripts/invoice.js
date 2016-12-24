var row_id = 0;

$(document).ready(function() {
$('.date').each(function() {
        $(this).datepicker({ dateFormat: 'yy-mm-dd' });
});
});

function invoiceFormSubmission()
{ 
	var dateval = new Date(document.getElementById("to").value);
	var fromdateval = new Date(document.getElementById("from").value);
	dateval.setDate(dateval.getDate() + 1);
	var salaryDate = dateval.getFullYear() + '-' + (("0" + (dateval.getMonth() + 1)).slice(-2)) + '-' + (("0" + dateval.getDate()).slice(-2));
	if (isNaN(dateval.getFullYear()) || isNaN(fromdateval.getFullYear())){
		alert("Please select valid date range");
	}
	else
	{
		var isFormSubmission = confirm("Are you sure want to generate invoice on " + salaryDate);
		if (isFormSubmission == true) {
			document.getElementById("generate").value = true; 
			document.getElementById("query_form").submit();
		}
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
			var i = id.substr(id.length-1);
			var prefix = id.substr(0, (id.length-1));
			el.attr('id', prefix+(+i+1));
			el.attr('name', prefix+(+i+1));
			//el.attr('value', prefix+(+i+1));
		}
	});/* working fine */
  
    if(tableId == "milestoneTable")
    {
	    var datePickerClone = $('.date', $rowClone);
		var datePickerCloneId = 'billdate' + rowlength;
		
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
	clearId = tableId == "milestoneTable" ? "milestone_id"+rowlength : (tableId == "txnTable" ? "txn_id"+rowlength : "item_id"+rowlength ) ;
	document.getElementById(clearId).value = "";
	if(document.getElementById('item_index' + rowlength) != null)
	{
		document.getElementById('item_index' + rowlength).innerHTML = rowlength; 
	}
	
	
}

function addAmount(fldId)
{
	var cloumnId = parseInt(fldId.replace(/[^0-9\.]/g, ''));
	var rate = document.getElementById('rate'+  cloumnId);
	var quantity = document.getElementById('quantity'+  cloumnId);
	if(rate.value != null && quantity.value != null)
	{
		document.getElementById("amount"+  cloumnId).innerHTML = rate.value * quantity.value;
	}
	
	var table = document.getElementById('invoiceTable');
	var len = table.rows.length;
	//var subtotal = 0;
	var total = 0;
	var count = 0;
	var tothash = new Object();
	for(var i = 1 ; i <= (len-1) ; i++)
	{
		var dropdown = document.getElementById("project_id"+i);
		var ddvalue = dropdown.options[dropdown.selectedIndex].value;
		tothash[ddvalue] = (tothash[ddvalue] == null ? 0 : tothash[ddvalue]) + parseInt($("#amount"+i).text());
		/*if(count == 0 || ddvalue == count)
		{
			//alert(" ddvalue : " + ddvalue + " count : " + count);
			subtotal = subtotal + parseInt($("#amount"+i).text());
			count = ddvalue;
		}*/
		total = total + parseInt($("#amount"+i).text());
		 
	}
	
	var taxtotal = 0;
	var taxTable = document.getElementById('taxTable');
	var taxlen = taxTable.rows.length;
	for(j=1 ;j < taxlen ; j++)
	{
		pjtId = document.getElementById('pjt_id'+j).value;
		var taxamount = tothash[pjtId] * (parseFloat($("#taxrate"+j).text()/100));
		taxtotal = taxtotal + taxamount;
		document.getElementById("taxamount"+ j).innerHTML = taxamount.toFixed(2); //total * parseFloat($("#taxrate"+j).text()); 
	}
	document.getElementById('invsubtotal').innerHTML = "SubTotal : " + total.toFixed(2);
	document.getElementById('invtotalamount').innerHTML = "Total : " + (taxtotal + total).toFixed(2);
	var roundtotal = Math.round(taxtotal + total);
	var roundlen = document.getElementById('taxTable').rows.length;
	if(roundlen > 1)
	{
		document.getElementById('roundamount').innerHTML = (roundtotal - (taxtotal + total)).toFixed(2);
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
					input.id = table.rows[i].cells[j].headers + i;
					input.name = table.rows[i].cells[j].headers + i;
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
					var input = document.getElementById(tableId).rows[i].cells[j].getElementsByTagName("*")[0];	
					input.id = table.rows[i].cells[j].headers + i;
					input.name = table.rows[i].cells[j].headers + i;					
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

//	var txn_debit = document.getElementById('txn_debit'+  fldId.slice(-1));
//	var txn_credit = document.getElementById('txn_credit'+  fldId.slice(-1));
	var addclm = parseInt(fldId.replace(/[^0-9\.]/g, '')) +1;	
	//var addclm = parseInt(fldId.slice(-1)) + 1 ;	
	var oldtable = document.getElementById("txnTable");
	var oldrowlength = oldtable.rows.length;
	if(addclm > 2 && addclm == oldrowlength )
	{
		invoiceAddRow('txnTable', 'txntotalrow');
	}		
	updateAmount();
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
		var txn_debit = document.getElementById('txn_debit'+i);
		var txn_credit = document.getElementById('txn_credit'+i);
		debval = txn_debit.value == "" ? 0 : parseInt(txn_debit.value);
		crdtval = txn_credit.value == "" ? 0 : parseInt(txn_credit.value);	
		
		if( i != rowlength-1)
		{
			debitAmount += debval ;
			creditAmount += crdtval ;
		}		
		if(txn_debit.value != "" && txn_credit.value == "" && i == 1)
		{
			isDebit = true;
		}
		var fieldId = (isDebit ? 'txn_credit' :  'txn_debit') + i;//(rowlength-1);
		if(i == (rowlength-1))
		{
			totalamount = isDebit ? debitAmount - creditAmount : creditAmount - debitAmount;
			totalamount = Math.abs(totalamount);
			var fieldId = ((isDebit && debitAmount > creditAmount) ? 'txn_credit' :  ((!isDebit && debitAmount > creditAmount) ? 'txn_credit' : 'txn_debit')) + i;//(rowlength-1);
			document.getElementById(fieldId).value = totalamount;			
		}
		totDebit += txn_debit.value == "" ? 0 : parseInt(txn_debit.value);
		totCredit +=  txn_credit.value == "" ? 0 : parseInt(txn_credit.value);	
		document.getElementById('debitTotal').innerHTML = totDebit;//isDebit ? totDebit : totDebit+totalamount;
		document.getElementById('creditTotal').innerHTML = totCredit;//isDebit ? totCredit : totCredit+totalamount;
	}
}

function txnAddrowValidation(tableId)
{
	var table = document.getElementById(tableId);
	var rowlength = table.rows.length;
	var isAddrow = false;
	for(var i = 1; i < 3; i++)
	{
		var txn_debit = document.getElementById('txn_debit'+i);
		var txn_credit = document.getElementById('txn_credit'+i);
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