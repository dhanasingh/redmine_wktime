 $(document).ready(function() {
	hideLogDetails(null);
	var entry = 'time_entry'
	var log_type = document.getElementById("log_type").value;
	if(log_type == 'E') entry = 'wk_expense_entry';
	if(['M', 'A', 'RA'].includes(log_type)) entry = 'wk_material_entry';
	if((document.getElementById(entry+'_project_id')) != null)
	{
		$('#'+entry+'_project_id').change(function(){
			var project=$(this);
			uid = document.getElementById('userId').value;
				loadSpentFors(project.val(), 'spent_for', false, uid)

			const allowedProjs = $('#allowedProjects').val();
			if(allowedProjs) allowedProjs.includes(this.value) ? $('#issuelogtable').show() : $('#issuelogtable').hide();
		});
	}

	//Time Tracking
	const spent_id = (new URL(window.location.href)).pathname.split('/')[2];
	if(parseInt(spent_id) > 0) $('#clock_action').val() == '' ? $('#issuelogtable').hide() : $('#issuelogtable').show();

	$('#'+entry+'_user_id, #'+entry+'_hours, #log_type, #'+entry+'_spent_on').change(function(){
		const logType = $('#log_type').val();
		var entry = 'time_entry'
		if(logType == 'E') entry = 'wk_expense_entry';
		if(['M', 'A', 'RA'].includes(logType)) entry = 'wk_material_entry';
		const clockAction = $('#clock_action').val();
		if((parseInt(spent_id) > 0 && clockAction == '') || (!(parseInt(spent_id) > 0) && clockAction == '') &&
			(($('#'+entry+'_user_id').length > 0 && $('#'+entry+'_user_id').val() != $('#current_user').val()) || ( logType == 'T' && $('#'+entry+'_hours').val() != '')) || (!(parseInt(spent_id) > 0) && $('#'+entry+'_spent_on').val() != new Date().toJSON().slice(0,10).replace(/-/g,'-')))
		{
			$('#issuelogtable').hide();
		}
		else if(['T', 'A'].includes(logType))
			$('#issuelogtable').show();
	});

	if($('#clock_action').val() == 'S'){
		$('#'+entry+'_spent_on').prop('disabled', true);
		$('#'+entry+'_hours').val(0.1).prop('disabled', true);
		$('#issueLogger').appendTo('#e_issueLogger');
		if($('#log_type').val() == 'T')
			$('#'+entry+'_hours').css({ float: 'left', 'margin-right': '10px' }).parent('p').append($('#logTimer'));
		else
			$('#logTimer').css({ 'padding-left': '10px', 'padding-right': '10px' }).insertAfter($('#product_quantity'));
	}

	$('#issueLogger').on('click', function(){
		var clock_action = $('#clock_action').val();
		var newDate = new Date();
		clock_action = clock_action == '' || clock_action == 'E' ? 'S' : 'E';
		$('#clock_action').val(clock_action);
		if(clock_action == 'S'){
			const spentOn = (newDate.toISOString()).split('T')[0];
			$('#'+entry+'_spent_on').val(spentOn).prop('disabled', true);
			$('#h_'+entry+'_spent_on').val(spentOn);
			$('#h_'+entry+'_spent_on').prop('name', ''+entry+'[spent_on]');
			$('#'+entry+'_hours').val(0.1).prop('disabled', true);
			$('#h_'+entry+'_hours').prop('name', ''+entry+'[hours]');
			$('.issueLog img').prop('src','/plugin_assets/redmine_wktime/images/finish.png');
			$('#issueLogger').appendTo('#e_issueLogger').css({ background: 'red' }).html('stop');
			$('#end_on').val('');
			$('#start_on').val(newDate.toISOString());
			// $('#td_start_on').html(newDate.toISOString().split('T'));
			$('#offSet').val(newDate.getTimezoneOffset());
			$('#new_'+entry+'').submit();
		}
		else{
			$('#'+entry+'_spent_on').prop('disabled', false);
			$('#h_'+entry+'_spent_on').prop('name', 'h_'+entry+'[spent_on]');
			$('#'+entry+'_hours').prop('disabled', false);
			$('#h_'+entry+'_hours').prop('name', 'h_'+entry+'[hours]');
			$('#e_issueLogger').html('');
			$('#offSet').val(newDate.getTimezoneOffset());
			$('.edit_'+entry+'').submit();
		}
		$('#clock_action').val(clock_action);
	});

	$('.edit_'+entry+' .new_'+entry+'').submit(function(){
		sessionStorage.setItem("spent_type", $('#log_type').val());
	});
});

function updateTotal(currId, nxtId, setId, currencyId)
{
	var currElement = document.getElementById(currId);
	var nxtElement = document.getElementById(nxtId);
	var totAmount = parseFloat(currElement.value) * parseFloat(nxtElement.value);
	document.getElementById(setId).innerHTML = document.getElementById(currencyId).innerHTML + totAmount.toFixed(2);
}