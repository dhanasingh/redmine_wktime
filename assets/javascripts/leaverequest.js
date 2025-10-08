$(function()
{
	leaveAvailable();
	$('#leave_type_id').change(function(){
		leaveAvailable();
	});
});

function leaveAvailable(){
    var issueID = $('#leave_type_id').val();
    var userID = $('#user_id').val();
	var url = "/wkleaverequest/get_leave_available_hours?issue_id="+ issueID +"&user_id=" + userID;
      $.ajax({
        url: url,
		type: 'get',
		success: function(data){
			var result = data[0];
            $('#AvailableHours').show();
            var label = ' <b>' + result.label + '</b>' + '<span style="padding-left: 5px;">' + result.hours + '</span>';
            $('#AvailableHours').html(label);
        },
        beforeSend: function(){
            $(this).parent().addClass('ajax-loading');
        },
        complete: function(){
            $(this).parent().removeClass('ajax-loading');
        }
	  });
}