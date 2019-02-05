function addrows()
{
	var lastEle = $('[id^=pollChoices]').last().attr('name');
	var row = parseInt(lastEle.replace("pollChoices","")) + 1;
	$("#lastrow").before("<tr><td></td><td align='left' style='padding-left:40px;'> <input type='text' name='pollChoices"+ row+"_' id='pollChoices"+ row +"_' size= 40 /><a title='Delete' href='javascript:deleterow("+ row +");'><img src='/images/delete.png'> </a> </td> </tr>");
	$('[id^=pollChoices'+ row +'_]').focus();
}
function deleterow(id)
{
	var totalrow = 3;	
	if ($('#poll_id').val() != ""){
		totalrow += 2;
	}
	var row = $('#newpoll').find('tr').length - totalrow;
	if (row > 1){
		$('[id^=pollChoices'+ id +'_]').closest('tr').remove();
	}
}