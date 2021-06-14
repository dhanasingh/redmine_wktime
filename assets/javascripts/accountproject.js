$(document).ready(function() {
	if(document.getElementById("billing_type") != null)
	{
		var billingtype = document.getElementById("billing_type").value;
		showorHide((billingtype == "FC" ? true : false), "billingschdules", null);
	}
	if(document.getElementById("applytax") != null)
	{
		var istax = document.getElementById("applytax").checked;
		showorHide(istax, "applicable_taxes", null);
	}

	/** initially load the datepicker in milestone bill date textfield **/
	$(".date").each(function() {
        $(this).datepicker({ dateFormat: "yy-mm-dd" });
	});
});

function showorHide(isshow, divId, divId1)
{
	if(isshow)
	{
		if(divId != null)
		{
			document.getElementById(divId).style.display = "block";
		}
		if(divId1 != null)
		{
			document.getElementById(divId1).style.display = "block";
		}

	}
	else {
		if(divId != null)
		{
			document.getElementById(divId).style.display = "none";
		}
		if(divId1 != null)
		{
			document.getElementById(divId1).style.display = "none";
		}
	}
}

function showQuantityDetails(){
	let searchParams = new URLSearchParams(window.location.search);
	let inventory_item_id = searchParams.has("inventory_item_id") && searchParams.get("inventory_item_id");
	let product_item_id = searchParams.has("product_item_id") && searchParams.get("product_item_id");

	$.ajax({
		url: "get_material_entries",
		type: "get",
		data: {inventory_item_id: inventory_item_id, product_item_id: product_item_id},
		success: function(resData){
			renderData(resData);
			$("#dialog" ).dialog({
				modal: true,
				title: title,
				width: "80%",
			});
		},
		beforeSend: function(){ $(this).addClass("ajax-loading"); },
		complete: function(){ $(this).removeClass("ajax-loading"); }
	});
}

function overrideComponents(chkboxelement){
	var chkboxid = chkboxelement.id;
	var isOverride = chkboxelement.checked;
	var id = chkboxid.replace("invoice_components_id_", "");
	var compValue = document.getElementById('invoice_components_value_'+id);
	compValue.disabled = !isOverride;
}