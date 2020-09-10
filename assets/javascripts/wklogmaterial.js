 $(document).ready(function() {	
	hideLogDetails(null);
	if(document.getElementById("time_entry_project_id") != null)
	{
		$('#time_entry_project_id').change(function(){
			var project=$(this);			
			uid = document.getElementById('userId').value;
				loadSpentFors(project.val(), 'spent_for', false, uid)
				
			const allowedProjs = $('#allowedProjects').val();
			allowedProjs.includes(this.value) ? $('#issuelogtable').show() : $('#issuelogtable').hide();
		});
	}

	//Time Tracking
	const spent_id = (new URL(window.location.href)).pathname.split('/')[2];
	if(parseInt(spent_id) > 0) $('#clock_action').val() == '' ? $('#issuelogtable').hide() : $('#issuelogtable').show();

	$('#time_entry_user_id, #time_entry_hours, #log_type, #time_entry_spent_on').change(function(){
		const logType = $('#log_type').val();
		const clockAction = $('#clock_action').val();
		if((parseInt(spent_id) > 0 && clockAction == '') || (!(parseInt(spent_id) > 0) && clockAction == '') &&
			(($('#time_entry_user_id').length > 0 && $('#time_entry_user_id').val() != $('#current_user').val()) || ( logType == 'T' && $('#time_entry_hours').val() != '')) || (!(parseInt(spent_id) > 0) && $('#time_entry_spent_on').val() != new Date().toJSON().slice(0,10).replace(/-/g,'-')))
		{
			$('#issuelogtable').hide();
		}
		else if(['T', 'A'].includes(logType))
			$('#issuelogtable').show();
	});

	if($('#clock_action').val() == 'S'){
		$('#time_entry_spent_on').prop('disabled', true);
		$('#time_entry_hours').val(0.1).prop('disabled', true);
		$('#issueLogger').appendTo('#e_issueLogger');
		if($('#log_type').val() == 'T')
			$('#time_entry_hours').css({ float: 'left', 'margin-right': '10px' }).parent('p').append($('#logTimer'));
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
			$('#time_entry_spent_on').val(spentOn).prop('disabled', true);
			$('#h_time_entry_spent_on').val(spentOn);
			$('#h_time_entry_spent_on').prop('name', 'time_entry[spent_on]');
			$('#time_entry_hours').val(0.1).prop('disabled', true);
			$('#h_time_entry_hours').prop('name', 'time_entry[hours]');
			$('.issueLog img').prop('src','/plugin_assets/redmine_wktime/images/finish.png');
			$('#issueLogger').appendTo('#e_issueLogger').css({ background: 'red' }).html('stop');
			$('#end_on').val('');
			$('#start_on').val(newDate.toISOString());
			// $('#td_start_on').html(newDate.toISOString().split('T'));
			$('#offSet').val(newDate.getTimezoneOffset());
			$('#new_time_entry').submit();
		}
		else{
			$('#time_entry_spent_on').prop('disabled', false);
			$('#h_time_entry_spent_on').prop('name', 'h_time_entry[spent_on]');
			$('#time_entry_hours').prop('disabled', false);
			$('#h_time_entry_hours').prop('name', 'h_time_entry[hours]');
			$('#e_issueLogger').html('');
			$('#offSet').val(newDate.getTimezoneOffset());
			$('.edit_time_entry').submit();
		}
		$('#clock_action').val(clock_action);
	});

	$('.edit_time_entry .new_time_entry').submit(function(){
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