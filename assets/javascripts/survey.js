function addrows(qINDEX, qID)
{
	var lastEleName = $('[id^=questionChoices_'+ qID + '_'+ qINDEX +']').last().attr('name');
	var namearr = lastEleName.split("_");
	var cINDEX = parseInt(namearr[4]) + 1;
	var param = qINDEX +","+ (qID == '' ? -1 : qID) +","+ cINDEX +", -1"
	var newele = "<tr><td></td><td align='left'> <input type='text' name='questionChoices_"+ qID +'_'+ qINDEX +"__"+cINDEX+"' id='questionChoices_"+ qID +'_'+ qINDEX +"__"+cINDEX+"' size= 40 /><a title='Delete' href='javascript:deleterow("+ param +");'><img src='/images/delete.png'> </a> </td> </tr>";
	$("#lastrow_"+qINDEX).before(newele);
	$('#questionChoices_'+ qID +'_'+ qINDEX +'__'+cINDEX).focus();
}

function deleterow(qINDEX, qID, cINDEX, cID)
{
	if(cID != '' && qID != ''){
		$('#deleteChoiceIds_'+qINDEX).val(function(){
			if(this.value == ''){
				return cID;
			}
			return this.value + ',' + cID;
		});
	}
	cID = cID == '-1' ? '' : cID;
	qID = qID == '-1' ? '' : qID;
	$('#questionChoices_'+ qID +'_'+ qINDEX +'_'+cID+'_'+cINDEX).closest('tr').remove();
}

function addquestion()
{
	var clonedDiv = $('#add_question_template').html();
	var qID = $(".surveyquestions").length;
	clonedDiv = clonedDiv.replace(/\QINDEX/g,qID);
	$('#add_link').before(clonedDiv);
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
}

$(function()
{
    $( "#accordion" ).accordion({
			collapsible: true,
			active: false,
			heightStyle: "content"
    });
} );