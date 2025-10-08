var basicAction = "";
var payrollId = 0;
var editedname = "";
var salaryCompDepLen = 1;
var dlgname = "";
var listbox = "";
$(document).ready(function(){
	if ($('#settings_basic').children().length != 0) {
		$("#basic_add").hide();
	}
	$("#settings_comp_del_ids").val("");
	$("#payroll-dlg" ).dialog({
		autoOpen: false,
		resizable: false,
		modal: false,
		width: 920,
		height: 450,
		overflow: 'auto',
		buttons: {
			"Ok": function() {
				var opt, desc = "", opttext = "";
				var name = $("#name").val();
				var salary_type = $("#salary_type").val();
				var cftype = $("#calculated_fields_type").val();
				var basic_field_factor = $("#basic_field_factor").val();
				var ledgerId = $("#db_ledger").val();
				var alertMsg = validation();
				if(!alertMsg){
					if('Add'== basicAction){
						opt = document.createElement("option");
						listbox.options.add(opt);
					}
					else if('Edit' == basicAction){ 						
						opt = listbox.options[listbox.selectedIndex];
					}
					if (name != ""){
						desc = ( (payrollId != 0 && basicAction == 'Edit') ?  payrollId + "|" : "|" )  + name
						opttext = name											
						if(dlgname != 'settings_basic' && dlgname != 'settings_calculated_fields'&& dlgname != 'settings_reimburse')
						{
							var compNames = getSalaryComps();
							compDepsVal = "";
							compDepsText = "";
							$.each(compNames, function(index, name){
								if(Array.isArray(name)){
									$("#salaryCompDeps .compDep").each(function(i){
										var compDepIndex = (this.id.split('_')[1]).toString();
										$.each(name, function(dep_index, dep_name){
											if(Array.isArray(dep_name)){
												$.each(dep_name, function(condIndex, condName){
													if(condIndex != 0){
														compDepsVal += ":";
														if(condIndex > 1) compDepsText += ":";
													}
													compDepsVal += $('#'+condName+compDepIndex).val();
													if($('#'+condName+compDepIndex).is("select") && condIndex != 0)
														compDepsText += $("#"+condName+compDepIndex+" :selected").text();
													else if(condIndex != 0)
														compDepsText += $("#"+condName+compDepIndex).val();
												});
											}
											else{
												compDepsVal += $('#'+dep_name+compDepIndex).val();
												if($('#'+dep_name+compDepIndex).is("select") && dep_index != 0)
													compDepsText += $("#"+dep_name+compDepIndex+" :selected").text();
												else if(dep_index != 0)
													compDepsText += $("#"+dep_name+compDepIndex).val();
												
												compDepsVal += "_";
												if(dep_index != 0) compDepsText += ":";
											}
										});
										if(i+1 < $("#salaryCompDeps .compDep").length){
											compDepsVal += "-";
											compDepsText += ":";
										}
									});
								}
								else{
									compDepsVal += $('#'+name).val();
									if($('#'+name).is("select") && index != 0)
										compDepsText += $('#'+name+' :selected').text();
									else if(index != 0)
										compDepsText += $('#'+name).val();
									compDepsVal += "|";
									if(index != 0) compDepsText += ":";
								}
							});
							desc = compDepsVal;
							opttext = compDepsText;
						}
						else if (dlgname == 'settings_basic'){
							desc = desc + "|"  + salary_type;
							opttext += (salary_type != "") ? ":" + $("#salary_type :selected").text() : "";
							opttext += ":" + (basic_field_factor == null ? 0 : basic_field_factor);
							opttext += (ledgerId != "") ? ":" + $("#db_ledger :selected").text() : "";
							desc += "|" + $("#basicCompDepID").val()  + "|"  + (basic_field_factor == null ? 0 : basic_field_factor)+
								"|" + ledgerId;
						}
						else if (dlgname == 'settings_reimburse'){
							opttext += (ledgerId != "") ? ":" + $("#db_ledger :selected").text() : "";
							desc += "|" + ledgerId;
						}
						else{
							desc = desc ;
							opttext = opttext ;
							desc = desc + "|"  + cftype;
							if (cftype != ""){
								opttext = opttext + " : " + $("#calculated_fields_type :selected").text();
							}
						}
					}
					opt.text =  opttext;
					opt.value = desc;						
					$( this ).dialog( "close" );	
				}
				else{

					err_msg = alert(alertMsg);
				}
				
			},
			Cancel: function() {
				$( this ).dialog( "close" );
			}
		}
	});	

	$("form").submit(function(){
		var compsTypeIDs = [ "settings_basic", "settings_allowances", "settings_deduction", "settings_calculated_fields", "settings_reimburse"];
		selectAllComponents(compsTypeIDs);
	});

	$("body").on("change","[class^='condElements_']", function(){
		cls_name = $(this).attr("class");
		var isblank = true;
		$('.' + cls_name + '').each(function() {
			if(this.value != "") isblank = false;
			return;
		});
		index = cls_name.split('_')[1];
		condID = $("#compDepConID_" + index).val();
		if(isblank && condID != ""){
			$('#settings_cond_del_ids').val(function(){
				if(this.value == ''){
					return condID;
				}
				return this.value + ',' + condID;
			});
		}
	});

	if ($('#settings_reimburse').children().length != 0) {
		$("#reimburse_add").hide();
	}

});

function payrollDialogAction(dlg, action)
{
	$("#salaryCompDeps").html("");
	$( "#payroll-dlg" ).dialog({ title: getTitle(dlg)});
	basicAction = action;
	dlgname = dlg;
	listbox = document.getElementById(dlgname);
	$("#ledgersLabel").html(dlg == "settings_deduction" ? lblcreditLedger : lbldebitLedger);
	if('settings_basic' == dlg){
		$("#basic_salary_type").show();
		$("#basic_factor").show();
		$("#table_payroll_dependent").hide();
		$("#payroll_frequency").hide();
		$("#payroll_start_date").hide();
		$('#calculatedFieldsType').hide();
		$('#payrollDBLedger').show();
		$("#addDeps").hide();
		if('Add' == action){
			editedname = "" ;
			$("#payroll-dlg").dialog("open");	
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >= 0){
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			payrollId = listboxArr[0];
			$("#name").val(listboxArr[1]);
			editedname = listboxArr[1];
			$("#salary_type").val(listboxArr[2]);
			$('#basicCompDepID').val(listboxArr[3]);
			$('#basic_field_factor').val(listboxArr[4]);
			$('#db_ledger').val(listboxArr[5]);
			$("#payroll-dlg").dialog("open");
		}
	    else if(listbox != null && listbox.options.length >0){
			alert(selectListAlertMsg);				
		}			
	}
	else if(('settings_allowances' == dlg) || ('settings_deduction' == dlg)){
		$("#payroll_start_date").show();
		$('#calculatedFieldsType').hide();
		$('#payrollDBLedger').show();
		$("#table_payroll_dependent").show();		
		$("#payroll_frequency").show();
		$("#basic_factor").hide();
		$("#basic_salary_type").hide();
		$("#addDeps").show();
		var emptyValueSet = getValueSet([])
		setupdialog(emptyValueSet);
		if('Add' == action){
			editedname = "" ;
			setupDependent(salaryCompDepLen);
			hideRecusiveComp(dlg, '');
			$("#payroll-dlg").dialog("open");
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0){
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			editedname = listboxArr[1];
			var  salaryComps = listbox.options[listbox.selectedIndex].value.split('|');
			salaryCompValueSet = getValueSet(salaryComps);
			setupDependent(salaryCompDepLen);
			setupdialog(salaryCompValueSet);
			hideRecusiveComp(dlg, listboxArr[0]);
			$( "#payroll-dlg" ).dialog( "open" )
		}
		else if(listbox != null && listbox.options.length >0){
			alert(selectListAlertMsg);				
		}
	}
	else if('settings_calculated_fields' == dlg){
		$("#basic_salary_type").hide();
		$("#table_payroll_dependent").hide();
		$("#payrollDBLedger").hide();
		$("#payroll_frequency").hide();
		$("#payroll_start_date").hide();
		$('#basic_factor').hide();
		$('#calculatedFieldsType').show();
		$("#addDeps").hide();
		if('Add' == action){
			editedname = "" ;
			$('#name').val('');
			$("#calculated_fields_type").val('BAT');
			$("#payroll-dlg").dialog("open");
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0){
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			payrollId = listboxArr[0];
			editedname = listboxArr[1];
			$('#name').val(listboxArr[1]);
			$('#calculated_fields_type').val(listboxArr[2]);
			$("#payroll-dlg").dialog("open");
		}
		else if(listbox != null && listbox.options.length >0){
			alert(selectListAlertMsg);				
		}
	}
	else if('settings_reimburse' == dlg){
		$("#basic_salary_type").hide();
		$("#table_payroll_dependent").hide();
		$("#payrollDBLedger").show();
		$("#payroll_frequency").hide();
		$("#payroll_start_date").hide();
		$('#basic_factor').hide();
		$('#calculatedFieldsType').hide();
		$("#addDeps").hide();
		if('Add' == action){
			editedname = "" ;
			$('#name').val('');
			$("#payroll-dlg").dialog("open");
		}
		else if('Edit' == action && listbox != null && listbox.options.selectedIndex >=0){
			var listboxArr = listbox.options[listbox.selectedIndex].value.split('|');
			payrollId = listboxArr[0];
			editedname = listboxArr[1];
			$('#name').val(listboxArr[1]);
			$('#db_ledger').val(listboxArr[2]);
			$("#payroll-dlg").dialog("open");
		}
		else if(listbox != null && listbox.options.length >0){
			alert(selectListAlertMsg);				
		}
	}
}

function selectAllComponents(compsTypeIDs){
	for(type of compsTypeIDs){
		var ddList = document.getElementById(type);
		if(ddList != null){ 
			for(i = 0; i < ddList.options.length; i++){
				ddList.options[i].selected = true;
			}
		}
	}
}

function getSalaryComps(){
	var dep_conds = ["compDepConID_", "condDepID_", "condOp_", "condFactor_", "condFactor2_"];
	var comp_deps = ["compDepID_", "depID_", "factorOp_", "factor_", dep_conds];
	var compNames = ["salaryCompID", "name", "frequency", "start_date", "db_ledger", comp_deps];
	return compNames;
}

function getValueSet(salaryComps){
	var valueSet = {};
	var compNames = getSalaryComps();
	$.each(compNames, function(index, name){
		if(Array.isArray(name)){
			var dep_valueSet = {};
			var depCondValueSet = {};
			var depsConds = index < salaryComps.length ? (salaryComps[index]).split("-") : [''];
			salaryCompDepLen = depsConds.length;
			$.each(depsConds, function(depsCondsIndex, depsCondsName){
				var depComps = depsCondsIndex < depsConds.length && depsConds[0] != '' ? depsCondsName.split("_") : [];
				depsCondsIndex += 1;
				$.each(name, function(dep_index, dep_name){
					if(Array.isArray(dep_name)){
						var depConds = dep_index < depComps.length ? (depComps[dep_index]).split(":") : [];
						$.each(dep_name, function(condIndex, condName){
							depCondValueSet[condName+depsCondsIndex] = condIndex < depConds.length ? depConds[condIndex] : '';
						});
					}
					else{
							dep_valueSet[dep_name+depsCondsIndex] = dep_index < depComps.length ? depComps[dep_index] : (dep_name == 'factorOp_' ? 'EQ' : '');
					}
				});
			});
			dep_valueSet["depConds"] = depCondValueSet;
			valueSet["depComps"] = dep_valueSet;
		}
		else{
			valueSet[name] = index < salaryComps.length ? salaryComps[index] : '';
		}
	});
	return valueSet;
}

function setupdialog(emptyValueSet){
	$.each(emptyValueSet, function(id, val){
		if(val != "" && val.constructor == Object){
			$.each(val, function(depID, depVal){
				if(depVal != "" && depVal.constructor == Object){
					$.each(depVal, function(condID, condVal){
						$('#'+condID).val(condVal);
					});
				}
				else{
					$('#'+depID).val(depVal);
				}
			});
		}
		else{
			$('#'+id).val(val);
		}
	});

	//For condition factor
	$("[id^='condOp_']").each(function(){
		showFactor(this);
	});
}

function getTitle(title){
	switch(title){
		case "settings_basic":
			return label_basic;
		case "settings_allowances":
			return label_allowances;
		case "settings_deduction":
			return label_deduction;
		case "settings_calculated_fields":
			return label_calculated_fields;
		case "settings_reimburse":
			return label_reimburse;
	}
}

function checkDuplicateComponent(newValue)
{
	isDuplicate = false;
	var listboxArr;	
	for(i=0; i < listbox.options.length; i++){
		listboxArr = listbox.options[i].value.split('|');	
		if(newValue.toLowerCase() == (listboxArr[1]).toLowerCase() && (editedname.toLowerCase() != newValue.toLowerCase()))
			isDuplicate = true;
	}
	return isDuplicate;
}

function removeSelectedValue(elementID)
{
	var listbox = document.getElementById(elementID);
	if(listbox != null && listbox.options.selectedIndex >= 0)
	 { 				
		if (confirm(attendanceAlertMsg))
		{
			//removes options from listbox
			for(var i = listbox.options.length-1; i >= 0; i--)
			{					
				if(listbox.options[i].selected)	
				{
					if(elementID == 'settings_allowances' || elementID == 'settings_deduction' || elementID == 'settings_calculated_fields'|| elementID == 'settings_reimburse')
					{
						var listboxArr = listbox.options[i].value.split('|');
						var payroll_ids = $('#settings_comp_del_ids').val();
						ids = payroll_ids == "" ? listboxArr[0] : (payroll_ids + "|" + listboxArr[0]);
						$('#settings_comp_del_ids').val(ids);
					}
					else if(elementID == 'invoice_components')
					{
						var listboxArr = listbox.options[i].value.split('|');
						var comp_ids = $('#invoice_comp_del_ids').val();
						ids = comp_ids == "" ? listboxArr[0] : (comp_ids + "|" + listboxArr[0]);
						$('#invoice_comp_del_ids').val(ids);
					}
					listbox.remove(i);
				}
			}
		}			
	}
	else if(listbox != null && listbox.options.length >0)
	{
		alert(selectListAlertMsg);
	}
}

function showFactor(thisEle){
	var index = thisEle.name.split("_")[1]
	if($(thisEle).val() == "BW")
		$("#condFactor2_"+index).show();
	else{
		$("#condFactor2_"+index).hide();
		$("#condFactor2_"+index).val('');
	}
}

function addDependent(){
	hideRecusiveComp(dlgname, $("#salaryCompID").val());
	var clonedTable = $("#compDepTemplate").html();
	var depsCount = $(".compDep").length;
	if(depsCount > 1){
		index = ($(".compDep").last().attr("id")).split("_")[1];
		depsCount = parseInt(index) + 1;
	}
	clonedTable = clonedTable.replace(/INDEX/g, depsCount);
	$("#salaryCompDeps").append(clonedTable);
}

function deleterow(index){
	depID = $("#compDepID_" + index).val();
	if(depID != ""){
		$('#settings_dep_del_ids').val(function(){
			if(this.value == ''){
				return depID;
			}
			return this.value + ',' + depID;
		});
	}
	$("#compDep_"+index).remove();
}

function setupDependent(salaryCompDepLen){
	var clonedTable = $("#compDepTemplate").html();
	for(var i=1; i <= salaryCompDepLen; i++){
		cloned = clonedTable.replace(/INDEX/g, i);
		$("#salaryCompDeps").append(cloned);
	}

	//For condition factor
	$("[id^='condOp_']").each(function(){
		showFactor(this);
	});
}

function validation(){
	var name = $("#name").val();
	var basic_field_factor = $("#basic_field_factor").val();
	var	frequency = $("#frequency").val();
	var	startdate = $("#start_date").val();
	var alertMsg = "";

	if(name == "")
		alertMsg += payroll_name_errormsg + "\n";

	if(checkDuplicateComponent(name))
		alertMsg += payroll_name + "\n";

	if( basic_field_factor == "" && dlgname == 'settings_basic')
		alertMsg += payroll_factor_errormsg + "\n";

		if( frequency && frequency != 'm' && startdate == "" && dlgname != 'settings_basic' &&
		dlgname != 'settings_calculated_fields' && !checkDuplicateComponent(name)){
		alertMsg +=  payroll_date_errormsg + "\n";
	}

	$(".compDep").each(function(){

		tabel_id = $(this).attr('id');
		splitedVal = tabel_id.split('_')
		if ($.isNumeric(splitedVal[1])){
			index = splitedVal[1]

			var	dependent_op = $("#factorOp_"+ index).val();
			var	dependent_id = $("#depID_"+ index).val();
			var	cond_dependent = $("#condDepID_"+ index).val();
			var	logic_condition = $("#condOp_"+ index).val();
			var	condition_value = $("#condFactor_"+ index).val();
			var other_cond_value =  (cond_dependent == "" || condition_value == "" || logic_condition == "") ? false : true ;

			if (dependent_id != "" && dependent_op == 'EQ')
				alertMsg +=  equalOpAlertMsg + "\n";

			if (logic_condition == 'BW')
				other_cond_value = $("#condFactor2_"+ index).val();

			if((cond_dependent || condition_value || logic_condition || other_cond_value) && (cond_dependent == "" || condition_value == "" || logic_condition == "" || other_cond_value == "") && 
				dlgname != 'settings_basic' && dlgname != 'settings_calculated_fields'){
				alertMsg +=  payroll_condition_errormsg + "\n";
			}
		}
	})
	return alertMsg;
}

function hideRecusiveComp(dlg, ownCompID){
	var url = '/wkpayroll/get_recursive_comp';
	$.ajax({
		url: url,
		type: 'get',
		data: { component_type: dlg },
		success: function(data){
			var data = $.parseJSON(data);
			data.push(parseInt(ownCompID));
			$("#salaryCompDeps .component option").each(function(){
				salComID = parseInt($(this).val());
				if(data.includes(salComID)) $(this).hide(data);
				else $(this).show();
			});
		} 
	});
}
