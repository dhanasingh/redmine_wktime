var row_id = 0;

$(document).ready(function() {
$('.date').each(function() {
        $(this).datepicker({ dateFormat: 'yy-mm-dd' });
});
});

function invoiceFormSubmission()
{ 
	var dateval = new Date(document.getElementById("to").value);
	dateval.setDate(dateval.getDate() + 1);
	var salaryDate = dateval.getFullYear() + '-' + (("0" + (dateval.getMonth() + 1)).slice(-2)) + '-' + (("0" + dateval.getDate()).slice(-2));
	var isFormSubmission = confirm("Are you sure want to generate invoice on " + salaryDate);
	if (isFormSubmission == true) {
		document.getElementById("generate").value = true; 
		document.getElementById("query_form").submit();
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
	clearId = tableId == "milestoneTable" ? "milestone_id"+rowlength : "item_id"+rowlength;
	document.getElementById(clearId).value = "";
	document.getElementById('item_index' + rowlength).innerHTML = rowlength; 
	
}

function addAmount()
{
	var rate = document.getElementById('rate'+ row_id);
	var quantity = document.getElementById('quantity'+ row_id);
	if(rate.value != null && quantity.value != null)
	{
		document.getElementById("amount"+ row_id).innerHTML = rate.value * quantity.value;
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
		document.getElementById("taxamount"+ j).innerHTML = taxamount; //total * parseFloat($("#taxrate"+j).text()); 
	}
	
	document.getElementById('invtotalamount').innerHTML = "Total : " + (taxtotal + total);
}

function deleteRow(tableId, totalrow)
{
    document.getElementById(tableId).deleteRow(row_id);	
	document.getElementById(totalrow).value = document.getElementById(totalrow).value - 1;
}

function openInvReportPopup(){
	var invId = document.getElementById('invoice_id').value;
	popupUrl = wkInvReportUrl + '&invoice_id=' + invId +'&is_report=true'
	window.open(popupUrl, '_blank', 'location=yes,scrollbars=yes,status=yes');
}