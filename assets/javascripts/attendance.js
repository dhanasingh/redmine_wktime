
function getTextBoxField(name, inputEl, splitVal){
    value = $.trim($(inputEl).text());
    var input = '<input id="txt_'+ name +'_'+splitVal[1]+'_'+splitVal[2]+'" name="'+ name +'_'+splitVal[1]+'_'+splitVal[2]+'"';
    input += 'type="text" value="' + value + '" maxlength="5" size="10" onchange="validateHrFormat(this);" />';
    input += '<input name="h_'+ name +'_'+splitVal[1]+'_'+splitVal[2]+'" id="h_'+ name +'_'+splitVal[1]+'_'+splitVal[2]+'"';
    input += 'type="hidden" value="' + value + '">';
    return input;
}

function validateHrFormat(inputEl){
    var splitVal = inputEl.id.split("_");
    var currentVal = $.trim($(inputEl).val()),
        clockInEl = $('#txt_clockin_'+splitVal[2]+'_'+splitVal[3]),
        clockOutEl = $('#txt_clockout_'+splitVal[2]+'_'+splitVal[3]),
        hoursEl = $('#hours_'+splitVal[2]+'_'+splitVal[3]),
        defaultValue = $('#h_'+inputEl.name).val(),
        clkInTime = $.trim($(clockInEl).val()),
        clkOutTime = $.trim($(clockOutEl).val()),
        err_msg = '';
    if(currentVal.match(/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/) == null){
        $(inputEl).val(defaultValue);
        err_msg += not_valid_errormsg;
    }else if(!clkInTime && clkOutTime){
        $(inputEl).val(defaultValue);
        err_msg += enter_clk_in_errormsg;
    }else if(clkInTime && !clkOutTime || !clkInTime && !clkOutTime){
        $(hoursEl).text("0.0");
    }else if(convertHoursToSecs(clkInTime) > convertHoursToSecs(clkOutTime)){
		$(inputEl).val(defaultValue);
		err_msg += greater_then_errormsg;
    }else{
        $(hoursEl).text(calculate_hours(clockInEl, clockOutEl));
    }
    if(err_msg){
        alert(err_msg);
    }
}

function bulkEdit(){
    var button = $('#editIcon').attr('action');
    if(button == 'Edit'){
        $('[id^="clockin_"]').each(function(){
            splitVal = this.id.split("_");
            clockInEl = $('#clockin_'+splitVal[1]+'_'+splitVal[2]);
            clockOutEl = $('#clockout_'+splitVal[1]+'_'+splitVal[2]);
            $('#editIcon').attr('action', 'Update').removeClass().addClass("icon icon-save");
            $('#editIcon').hide();
            $('#saveIcon').show();
            $(this).parent('tr').removeClass("user locked");
            let userID = $('#userID_'+splitVal[1]+'_'+splitVal[2]).val();
            if(userID != current_user_id){
                $(clockInEl).html(getTextBoxField('clockin', clockInEl, splitVal));
                $(clockOutEl).html(getTextBoxField('clockout', clockOutEl, splitVal));
            }
        });
    }
    else if(button == 'Update'){
        var url = '/wkattendance/save_bulk_edit';
        $.ajax({
            url: url,
            type: 'post',
            data: $('#clockList').serialize(),
            cache: false,
            success: function(data){
                if(data){
                    alert(data);
                } else {
                    $("#query_form").submit();
                    return false;
                }
            },
            beforeSend: function(){
                $(this).parent().addClass('ajax-loading');
            },
            complete: function(){
                $(this).parent().removeClass('ajax-loading');
                $('#editIcon').attr('action', 'Edit').removeClass().addClass("icon icon-edit");
            }
        });
    }
}

function calculate_hours(startEl, endEl){
    var time1 = $(startEl).val().split(':'), time2 = $(endEl).val().split(':');
    var mins = 0, mins1 = parseInt(time1[1], 10),
        mins2 = parseInt(time2[1], 10);
    var hours = parseInt(time2[0], 10) - parseInt(time1[0], 10);

    // get hours
    if(hours < 0) hours = 24 + hours;

    // get minutes
    if(mins2 >= mins1) {
        mins = mins2 - mins1;
    }
    else {
        mins = (mins2 + 60) - mins1;
        hours--;
    }

    // convert to fraction of 60
    mins = mins / 60;

    hours += mins;
    hours = hours.toFixed(2);
    return hours;
}

function convertHoursToSecs(timeStr){
    var splits = timeStr.split(':'); // split it at the colons

    // minutes are worth 60 seconds. Hours are worth 60 minutes.
    var seconds = (+splits[0]) * 60 * 60 + (+splits[1]) * 60;
    return seconds;
}