function addrows()
{
	var lastEle = $('[id^=surveyChoices]').last().attr('name');
	var row = parseInt(lastEle.replace("surveyChoices","")) + 1;
	$("#lastrow").before("<tr><td></td><td align='left' style='padding-left:40px;'> <input type='text' name='surveyChoices"+ row+"_' id='surveyChoices"+ row +"_' size= 40 /><a title='Delete' href='javascript:deleterow("+ row +");'><img src='/images/delete.png'> </a> </td> </tr>");
	$('[id^=surveyChoices'+ row +'_]').focus();
}
function deleterow(id)
{
	var totalrow = 3;	
	if ($('#survey_id').val() != ""){
		totalrow += 2;
	}
	var row = $('#newsurvey').find('tr').length - totalrow;
	if (row > 1){
		$('[id^=surveyChoices'+ id +'_]').closest('tr').remove();
	}
}