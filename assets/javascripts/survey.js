function addrows(qID)
{
	var lastEle = $('[id^=surveyChoices_'+ qID +']').last().attr('name');
	var row = parseInt(lastEle.replace("surveyChoices_"+ qID+"_", "")) + 1;
	$("#lastrow_"+qID).before("<tr><td></td><td align='left' style='padding-left:40px;'> <input type='text' name='surveyChoices_"+ qID+"_"+ row +"_' id='surveyChoices_"+ qID +"_"+ row +"_' size= 40 /><a title='Delete' href='javascript:deleterow("+ qID +","+ row +");'><img src='/images/delete.png'> </a> </td> </tr>");
	$('[id^=surveyChoices_'+ qID +'_'+ row +'_]').focus();
}

function deleterow(qID, id)
{
	$('[id^=surveyChoices_'+ qID +'_'+ id +'_]').closest('tr').remove();
}

$(function()
{
    $( "#accordion" ).accordion({
			collapsible: true,
			active: false,
			heightStyle: "content"
    });
} );

function addquestion()
{
	var clonedDiv = $('#add_question_template').html();
	var qID = $(".surveyquestions").length;
	clonedDiv = clonedDiv.replace(/\QID/g,qID);
	$('#add_link').before(clonedDiv);
}