function addrows(qINDEX, qID)
{
	var lastEleName = $('[id^=questionChoices_'+ qID + '_'+ qINDEX +']').last().attr('name');
	var namearr = lastEleName.split("_");
	var cINDEX = parseInt(namearr[4]) + 1;
	var param = qINDEX +","+ (qID == '' ? -1 : qID) +","+ cINDEX +", -1"
	var newele = "<tr><td></td><td></td><td align='left'> <input type='text' name='questionChoices_"+ qID +'_'+ qINDEX +"__"+cINDEX+"' id='questionChoices_"+ qID +'_'+ qINDEX +"__"+cINDEX+"' size='40%' maxlength='255'/><a title='Delete' href='javascript:deleterow("+ param +");'><img src='/images/delete.png'> </a> </td> </tr>";
	$("#lastrow_"+qINDEX).before(newele);
	$('#questionChoices_'+ qID +'_'+ qINDEX +'__'+cINDEX).focus();
}

function deleterow(qINDEX, qID, cINDEX, cID)
{
	
	cID = cID == '-1' ? '' : cID;
	qID = qID == '-1' ? '' : qID;
	
	if(cID != '' && qID != ''){
		$('#deleteChoiceIds_'+qINDEX).val(function(){
			if(this.value == ''){
				return cID;
			}
			return this.value + ',' + cID;
		});
	}
	$('#questionChoices_'+ qID +'_'+ qINDEX +'_'+cID+'_'+cINDEX).closest('tr').remove();
}

function addquestion()
{
	var clonedDiv = $('#add_question_template').html();
	if($(".surveyquestions").length > 1){
		var lastEleName = $('[id^=questionName_]').eq(-2).attr('name');
		var namearr = lastEleName.split("_");console.log(namearr)
		var qID = parseInt(namearr[2]) + 1;
	}
	else{
		var qID = $(".surveyquestions").length
	}
	clonedDiv = clonedDiv.replace(/\SINDEX/g,qID);
	clonedDiv = clonedDiv.replace(/\QINDEX/g,qID);
	$('#add_link').before(clonedDiv);
	reOrderIndex();
}

function deletequestion(qINDEX, qID)
{
	if(qID != ''){
		$('#delete_question_ids').val(function(){
			if(this.value == ''){
				return qID;
			}
			return this.value + ',' + qID;
		});
	}
	$('#QuestionID_'+ qINDEX ).remove();
	reOrderIndex();
}

function reOrderIndex(){
	
	$('.indexNo').each(function(index){
		$(this).html('<b>'+(index+1)+'.</b>');
	});
}

$(function()
{
    $( "#accordion" ).accordion({
			collapsible: true,
			active: false,
			heightStyle: "content"
	});

	$('[id^=question_type_]').each(function(){
		check_question_type(((this.name).split('_'))[2]);
	});
	
});

function check_question_type(qIndex){
	var question_type = $('#question_type_'+qIndex).val();
	$('[id^=questionChoices_]').each(function(){
		var ele_index = ((this.name).split('_'))[2];
		var choice_id = ((this.name).split('_'))[3];
		var question_id = ((this.name).split('_'))[3];

		if((question_type == 'TB' || question_type == 'MTB') && ele_index == qIndex){
			$(this).parents('tr').hide();
			$('[id^=lastrow_'+qIndex+']').hide();

			if(choice_id != ''){
				$('#deleteChoiceIds_' + qIndex).val(function(){
					var choice_IDs = (this.value).split(',');
					var return_value = this.value;

					if($.inArray(choice_id, choice_IDs) == -1){
							return_value = (return_value == '') ? choice_id : (return_value + ',' + choice_id);
					}
					return return_value;
				});
			}
			else{
				$(this).val('');
			}
		}
		else if(ele_index == qIndex){
			$(this).parents('tr').show();
			$('[id^=lastrow_'+qIndex+']').show();

			if(choice_id != '' && $('#deleteChoiceIds_' + qIndex).val() != ''){
				$('#deleteChoiceIds_' + qIndex).val(function(){
					var choice_IDs = (this.value).split(',');
					var return_value = '';
					$.each(choice_IDs, function(index, choiceID){
						
						if(choice_id != choiceID)
							return_value = (return_value == '') ? choiceID : (return_value + ',' + choiceID);
					});
					return return_value;
				});
			}
		}
	});
}

function validateSurveyFor(){
	
	var surveyFor = $('#survey_for').val();
	var surveyForID = $('#survey_for_id').val();
	if(surveyForID != '' && surveyFor != ''){
	var URL = "/wksurvey/survey_for_auto_complete?surveyFor="+ surveyFor +"&surveyForID="+surveyForID+"&method=filter";
      $.ajax({
        url: URL,
		type: 'get',
		success: function(data){
			var result = data[0];
			if(data.length > 0){
				$('#SurveyFor').show();
				var label = '<b>' + result.label + '</b>';
				$('#SurveyFor').html(label);
				$('#IsSurveyForValid').val(true);
			}
			else{
				$('#SurveyFor').hide();
				$('#IsSurveyForValid').val(false);
			}
		}
	  });
	}
	else if(surveyForID == '' || surveyFor == ''){
				$('#SurveyFor').hide();
				$('#IsSurveyForValid').val(false);
	}
}

$(document).ready(function(){
	$('#survey_for').change(function(){
		$('#survey_for_id').val('');
	});

	validateSurveyFor();
		
	$('#survey_for_id, #survey_for').change(function(){
		validateSurveyFor();
	});
});

observeAutocompleteField('survey_for_id',
	function(request, callback) {
		var url = "/wksurvey/survey_for_auto_complete?surveyFor="+ $('#survey_for').val() +"&surveyForID="+ $('#survey_for_id').val()+"&method=search";
		var data = {
			term: request.term
		};

		data['scope'] = 'all';
			
		$.get(url, data, null, 'json')
			.done(function(data){
				callback(data);
			})
			.fail(function(jqXHR, status, error){
				callback([]);
			});
	},
	{
		select: function(event, ui) {
			$('#SurveyFor').text('');
			$('#survey_for_id').val(ui.item.value).change();
		}
	}
);