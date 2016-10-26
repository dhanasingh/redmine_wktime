var row_id = 0;

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

function InvoiceaddRow()
{
	var table = document.getElementById('invoiceTable');
    var new_row = table.rows[1].cloneNode(true);
    var len = table.rows.length;
	var colCount = table.rows[0].cells.length;
	//new_row.cells[5].innerHTML = '0.00';
	for(var i=0; i<colCount; i++) 
	{  
	/*	var isclone = true;
		if(i == 2)
		{
			isclone = false;
		}
		else if( i == 5)
		{
			new_row.cells[5].innerHTML = '0.00';
			alert("test : " + i);
			var input = new_row.cells[5].getElementsByTagName('label')[0];
			input.value="99";
			isclone = false;
		}
		if(isclone)
		{*/
			var input = new_row.cells[i].getElementsByTagName("*")[0];			
			input.id = table.rows[1].cells[i].headers + len;
			input.name = table.rows[1].cells[i].headers + len;
			if(i == 1) {
				input.value = new_row.cells[1].innerHTML = len; 
			} 
			else{
				input.value = "";
			}
		//}		
	}
	document.getElementById('totalrow').value = len;
    table.appendChild( new_row );	 
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

function deleteRow(row)
{
    document.getElementById('invoiceTable').deleteRow(row_id);
	document.getElementById('totalrow').value = document.getElementById('totalrow').value - 1;
}