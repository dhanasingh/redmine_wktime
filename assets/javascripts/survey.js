$.widget.bridge("uiAccordion", $.ui.accordion);
$(function () {
	$('input[type=text]').blur();
	$("#accordion").uiAccordion({
		icons: { "header": "ui-icon-circle-triangle-e", "activeHeader": "ui-icon-circle-triangle-s" },
		collapsible: true,
		heightStyle: "content"
	});

	$(".group-accordion-item").uiAccordion({
		icons: { "header": "ui-icon-circle-triangle-e", "activeHeader": "ui-icon-circle-triangle-s" },
		collapsible: true,
		active: true,
		heightStyle: "content"
	});

	$('#groups_container').find('.group-accordion-header')
		.first().addClass('ui-accordion-header-active ui-state-active');
	$('#groups_container').find('.group-accordion-content').first().show();

	if ($('#survey_status').val() != 'O')
		$('.icon-email-add').hide();

	$('#survey_for').change(function () {
		$('#survey_for_id').val('');
	});

	validateSurveyFor();

	$('#survey_for_id, #survey_for').change(function () {
		validateSurveyFor();
	});

	$("#reminder-email-dlg").dialog({
		autoOpen: false,
		resizable: false,
		modal: true,
		width: 380,
		buttons: [
			{
				text: 'Ok',
				id: 'btnOk',
				click: function () {

					var email_notes = $('#email_notes').val();
					var survey_id = $('#survey_id').val();
					var user_group = $('#user_group').val();
					var includeUserGroup = $('#includeUserGroup').prop("checked");
					var additional_emails = $('#additional_emails').val();
					var isNotValid = false;

					if (additional_emails != '') {
						additional_emails = additional_emails.split(';');
						$.each(additional_emails, function (index, email) {
							if (!validateEmail(email))
								isNotValid = true;
						});
					}

					if (isNotValid || (additional_emails == '' && !includeUserGroup)) {
						alert('Validation failed');
						return false;
					}
					var url = '/wksurvey/email_user';
					$.ajax({
						url: url,
						type: 'get',
						data: {
							user_group: user_group, survey_id: survey_id, email_notes: email_notes, additional_emails: additional_emails,
							includeUserGroup: includeUserGroup
						},
						success: function (data) {
							if (data != "ok") alert(data);
							$("#reminder-email-dlg").dialog("close");
						},
						error: function (xhr, status, error) {
							$('#email_notes').val('');
						},
						beforeSend: function () {
							$(this).parent().addClass('ajax-loading');
						},
						complete: function () {
							$(this).parent().removeClass('ajax-loading');
						}
					});
				}
			},
			{
				text: 'Cancel',
				id: 'btnCancel',
				click: function () {
					$(this).dialog("close");
				}
			}]
	});

	showHideRecurEvery();
	$('#recur').change(function () {
		showHideRecurEvery();
	});

	$('#review').on('change', function () {
		if ($('#review:checked').val())
			$('.revieweronly').show();
		else {
			$('.revieweronly').hide();
			$("input[id^='reviewerOnly_']").each(function () {
				$(this).prop("checked", false);
			});
		}
	});
	$('#review').trigger("change");

	$("#add-grp-name").dialog({
		autoOpen: false,
		resizable: false,
		modal: true,
		buttons: [
			{
				text: 'Ok',
				id: 'btnOk',
				click: function () {
					$("#closedResp_form").submit();
				}
			},
			{
				text: 'Cancel',
				id: 'btnCancel',
				click: function () {
					$(this).dialog("close");
				}
			}]

	});

	//To render without choice question, append the choice next to question label
	$('[id^=tr_question_]').each(function () {
		const id = (this.id.split('_')).pop();
		if ($('.tr_choice_' + id).length == 1 && $('.td_choice_name_' + id).text().length == 0)
			$(this).append($('.tr_choice_' + id).contents());
	});

	var radio = false;
	//Uncheck If single Radio button/Check box element present
	$("input:radio").mouseup(function () {
		radio = $(this).is(':checked');
	}).click(function () {
		if (radio) $(this).prop("checked", false);
	});

	reOrderIndex(false);
});

function reOrderIndex(onlyVisible = true) {
	var visibleFilter = (onlyVisible === true) ? ':visible' : '';
	var groupCounter = 0;

	$('.accordion ,.group-accordion-item:visible').each(function () {
		groupCounter++;
		// 1. Header name change
		var $groupHeader = $(this).find('.group-accordion-header');
		var currentText = $groupHeader.text().trim();
		var newText = '';

		if (/^Group\s*[-]?\s*\d+$/i.test(currentText)) {
			newText = currentText.replace(/Group\s*[-]?\s*\d+/i, 'Group-' + groupCounter);
			const $iconElem = $groupHeader.find('#group-name');

			if ($iconElem.length) {
				$iconElem.text(newText);
			}
		}

		var questionCounter = 0;
		// 2. Process grouped questions
		var $groupContainer = $(this).find('.group-questions');
		if ($groupContainer.length) {
			$groupContainer.find('.surveyquestion' + visibleFilter).each(function () {
				questionCounter++;
				$(this).find('td.indexNo').html('<b>' + groupCounter + '.' + questionCounter + '.</b>');
			});
		}
	});

	// 3. Process ungrouped questions
	var ungropquestionCounter = 0;
	$('.ungrouped-questions .surveyquestion' + visibleFilter).each(function () {
		ungropquestionCounter++;
		$(this).find('td.indexNo').html('<b>' + ungropquestionCounter + '.</b>');
	});
}

function questionTypeChanged(dropdown) {
	const $select = $(dropdown);
	const value = $select.val();
	const $row = $select.closest("tr");
	const $choiceRows = $row.nextUntil("tr:has(select[name*='question_type'])");
	const $pointsCell = $row.find('.text-points');

	// Extract group and question indices from the select name
	const nameAttr = $select.attr("name");
	const match = nameAttr.match(/\[wk_survey_que_groups_attributes\]\[(\d+)\]\[wk_survey_questions_attributes\]\[(\d+)\]/);
	const groupIndex = match ? match[1] : "0";
	const questionIndex = match ? match[2] : "0";

	if (value === "RB" || value === "CB") {
		$choiceRows.show();
		const destroyField = $pointsCell.find("input[name*='[_destroy]']");
		if (destroyField.length > 0) destroyField.first().val('1');
		$pointsCell.css('display', 'none');

		if ($choiceRows.filter(".choice-row").length === 0) {

			// Build new choice row with correct indices
			const newRow = `
        <tr class="choice-row">
          <td></td>
          <th align="left">Choice</th>
          <td align="left" style="display:flex;">
            <input type="hidden" name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][1][id]">
            <input size="40" maxlength="255" type="text"
                   name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][1][name]">
          </td>
          <td align="left">
            <input size="5" maxlength="10" type="text"
                   name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][1][points]">
          </td>
        </tr>
      `;

			const $lastChoice = $row.nextAll(".choice-row").last();
			if ($lastChoice.length) {
				$lastChoice.after(newRow);
			} else {
				$row.after(newRow);
			}

			console.log("   ✅ Default choice row inserted");
		}
	} else {
		console.log("   Hiding choice rows and removing them");
		$choiceRows.hide();
		$pointsCell.css('display', 'inline-block');
		if ($choiceRows.length) {
			$choiceRows.filter(".choice-row").each(function () {
				const destroyField = this.querySelector("input[name*='[_destroy]']");
				if (destroyField) destroyField.value = '1';
				this.style.display = 'none';
			});
			const nextIndex = $choiceRows.length;
			const inputHtml = `
				<input type="hidden"
					name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][${nextIndex}][name]">
				<input type="text" size="5" maxlength="10"
					name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][${nextIndex}][points]">`;
			$pointsCell.html(inputHtml);
		}
	}
}

function addChoiceRow(link) {
	const adderRow = link.closest('tr');
	const table = adderRow.closest('table');
	const questionSelect = table.querySelector("select[name*='question_type']");
	const nameAttr = questionSelect?.name || '';
	const match = nameAttr.match(/\[wk_survey_que_groups_attributes\]\[(\d+)\]\[wk_survey_questions_attributes\]\[(\d+)\]/);
	const groupIndex = match?.[1] || '0';
	const questionIndex = match?.[2] || '0';

	const choiceRows = table.querySelectorAll('.choice-row');
	const nextIndex = choiceRows.length;

	const newRow = document.createElement('tr');
	newRow.className = 'choice-row';
	newRow.innerHTML = `
    <td></td>
		<th align="left"></th>
    <td align="left" style="display:flex;">
      <input type="text" size="40" maxlength="255"
        name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][${nextIndex}][name]">
				<a title="Delete" href="javascript:void(0);" onclick="this.closest('tr').remove()" style="margin-left:10px;">`+ delImg + `</a>
		</td>
		<td align="left">
      <input type="text" size="5" maxlength="10"
        name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][${nextIndex}][points]">
    </td>
  `;

	adderRow.parentNode.insertBefore(newRow, adderRow);
}

// Delete row
function DeleteChoice(link) {
	const row = link.closest("tr");
	const destroyField = row.querySelector("input[name*='[_destroy]']");
	if (destroyField) destroyField.value = '1';
	row.style.display = 'none';
}

function DeleteGroup(element) {
	const container = element.closest('.group-accordion-item') || element.closest('.surveyquestion') || element.closest('tr');
	const destroyField = container.querySelector('input[name*="_destroy"]');

	if (!confirm(deleteGrp)) return;

	if (destroyField) {
		destroyField.value = '1';
	}
	container.style.display = 'none';
	reOrderIndex(false);
};

function DeleteQuestion(element) {
	const $el = $(element);
	const $groupContainer = $el.closest('.group-ungrouped-questions');

	if ($groupContainer.length) {
		const hasGroupHeader = $groupContainer.find('.group-accordion-header').length > 0;
		const questionCount = $groupContainer.find('.surveyquestion:visible').length;

		if (hasGroupHeader && questionCount <= 1) {
			alert(deleteGrpQuesWarning);
			return;
		}
	}

	if (!confirm(deleteQues)) return;

	const $question = $el.closest('.surveyquestion').length ? $el.closest('.surveyquestion') : $el.closest('tr');

	const $destroyField = $question.find('input[name*="_destroy"]');
	if ($destroyField.length) {
		$destroyField.val('1');
	}
	$question.hide();
	reOrderIndex();
}

function addUngroupedQues() {
	const template = document.getElementById("group_template");
	const clone = template.content.cloneNode(true);
	const $tempContainer = $('<div>').append(clone);

	const $tempQues = $tempContainer.find('.surveyquestion');

	const $unGroup = $('<div class="ungrouped-questions">').append($tempQues);
	const $unGroupQues = $('<div class="group-ungrouped-questions">').append($unGroup);
	const $temp = $('<div>').append($unGroupQues);

	// 1. Find the elements to remove (label and input) inside the first <td>
	const $inputToRemove = $tempContainer.find(".group-actions");
	const $linkToRemove = $tempContainer.find(".add-question-link");
	const $headerToRemove = $tempContainer.find(".group-accordion-header");

	if ($inputToRemove.length > 0) {
		$inputToRemove.remove();
		$linkToRemove.remove();
		$headerToRemove.remove();
	}

	let html = $temp.html();

	const groupIndex = $(".group-ungrouped-questions").length + 1;

	html = html.replace(/__GROUP_INDEX__/g, groupIndex)
		.replace(/__QUESTION_INDEX__/g, 1);

	$("#groups_container").append(html);
	reOrderIndex();
}

// Add a new group dynamically
function addSurveyGroup() {
	const template = document.getElementById("group_template");

	const clone = template.content.cloneNode(true);
	const groupIndexNo = $(".group-ungrouped-questions .group-questions").length + 1;
	const groupIndex = $(".group-ungrouped-questions").length + 1;

	let html = $('<div>').append(clone).html();
	html = html.replace(/__GROUP_INDEX__/g, groupIndex)
		.replace(/__QUESTION_INDEX__/g, 1)
		.replace(/__GROUP_INDEX_NO__/g, groupIndexNo);

	$("#groups_container").append(html);

	initializeGroupAccordion(groupIndex);
	console.log("New group added for edit page:", groupIndex);
	reOrderIndex(false);
}

function initializeGroupAccordion(groupIndex) {
	const $questionsAccordion = $("#group-" + groupIndex);

	$questionsAccordion.uiAccordion({
		icons: { "header": "ui-icon-circle-triangle-e", "activeHeader": "ui-icon-circle-triangle-s" },
		collapsible: true,
		active: false,
		heightStyle: "content"
	});
	$questionsAccordion.uiAccordion("refresh");
}


function addQuestions(button) {
	const group = button.closest('.group-questions');
	const template = group.querySelector('#question-template');
	if (!group || !template) {
		console.error('Missing elements');
		return;
	}

	// Clone template
	const clone = template.content.cloneNode(true);
	const wrapper = document.createElement('div');
	wrapper.appendChild(clone);

	let html = wrapper.innerHTML;
	const existingQuestions = group.querySelectorAll('.surveyquestion').length;
	const newId = existingQuestions + 1;
	html = html.replace(/NEW_RECORD/g, newId).replace(/__GROUP_INDEX__/g, 1)
		.replace(/__QUESTION_INDEX__/g, 1);

	const addLink = group.querySelector('.add-question-link');
	if (addLink) {
		addLink.insertAdjacentHTML('beforebegin', html);
	} else {
		group.insertAdjacentHTML('beforeend', html);
	}
	reOrderIndex();
}

// Update group header when name changes
function updateGroupHeader(input) {
	const header = input.closest('.group-accordion-item').querySelector('.group-accordion-header');
	const nameElement = header.querySelector('#group-name');

	if (nameElement) {
		nameElement.textContent = input.value || 'Group Name';
	}
}


function validateSurveyFor() {

	var surveyFor = $('#survey_for').val();
	var surveyForID = $('#survey_for_id').val();
	if (surveyForID != '' && surveyFor != '') {
		var URL = "/wksurvey/find_survey_for?surveyFor=" + surveyFor + "&surveyForID=" + surveyForID + "&method=filter";
		$.ajax({
			url: URL,
			type: 'get',
			success: function (data) {
				var result = data[0];
				if (data.length > 0) {
					$('#SurveyFor').show();
					var label = '<b>' + result.label + '</b>';
					$('#SurveyFor').html(label);
					$('#IsSurveyForValid').val(true);
				}
				else {
					$('#SurveyFor').hide();
					$('#IsSurveyForValid').val(false);
				}
			}
		});
	}
	else if (surveyForID == '' || surveyFor == '') {
		$('#SurveyFor').hide();
		$('#IsSurveyForValid').val(false);
	}
}

observeAutocompleteField('survey_for_id', function (request, callback) {
	var url = "/wksurvey/find_survey_for?surveyFor=" + $('#survey_for').val() + "&surveyForID=" + $('#survey_for_id').val() + "&method=search";
	var data = {
		term: request.term
	};

	data['scope'] = 'all';

	$.get(url, data, null, 'json')
		.done(function (data) {
			callback(data);
		})
		.fail(function (jqXHR, status, error) {
			callback([]);
		});
},
	{
		select: function (event, ui) {
			$('#SurveyFor').text('');
			$('#survey_for_id').val(ui.item.value).change();
		}
	}
);

function showConfirmationDlg() {

	$('#email_notes').val('');
	$('#additional_emails').val('');
	$("#reminder-email-dlg").dialog("open");
}

function addGrpName() {
	$("#add-grp-name").dialog("open");
}
function validateEmail($email) {
	var emailReg = /^([\w-\.]+@([\w-]+\.)+[\w-]{2,4})?$/;
	return emailReg.test($email);
}

function showHideRecurEvery() {
	if ($("#recur").prop("checked")) {
		$("#tr_recur_every").show();
		$("#recur_every").prop('required', true);
	}
	else {
		$("#tr_recur_every").hide();
		$("#recur_every").prop('required', false);
	}
}

function survey_submit() {
	$("[name^='survey_sel_choice_']").each(function () {
		$(this).prop('required', false);
	});
	$("#commit").val("Save");
	$("#survey_form").submit();
}

function validation() {
	var isUnAnswered = false;
	var checkBoxClass = null;
	$("[name^='survey_sel_choice_']:required").each(function () {
		switch (this.type) {
			// case "text":
			// 	if($(this).val() == ""){
			// 		isUnAnswered = true;
			// 		return false;
			// 	}
			// break;
			case "radio":
				if (!$.isNumeric($("input[name='" + this.name + "']:checked").val())) {
					isUnAnswered = true;
					return false;
				}
				break;
			// case "textarea":
			// 	if($(this).val() == ""){
			// 		isUnAnswered = true;
			// 		return false;
			// 	}
			// break;
			case "checkbox":
				let answered = false;
				if (checkBoxClass != this.className) {
					checkBoxClass = this.className;
					$("." + this.className).each(function () {
						answered = answered || this.checked;
					});
					if (!answered) {
						isUnAnswered = true;
						return false;
					}
				}
				break;
			default:
				if ($(this).val() == "") {
					isUnAnswered = true;
					return false;
				}
		}
	});

	if (!isUnAnswered && confirm(warn_survey_submit)) {
		$("#commit").val("Submit");
		$("#survey_form").submit();
	}
	else if (isUnAnswered) {
		alert(warn_survey_mandatory);
	}
}

function updateTotalPoints() {
	let totalpts = 0;
	//For RB, CB
	document.querySelectorAll("input[type='checkbox'][data-points], input[type='radio'][data-points]").forEach(function (el) {
		let elementid = '.' + el.id;
		if (el.checked) {
			totalpts += parseFloat(el.dataset.points) || 0;
			document.querySelectorAll(elementid).forEach(span => {
				span.style.fontWeight = 'bold';
			});
		} else {
			document.querySelectorAll(elementid).forEach(span => {
				span.style.fontWeight = 'normal';
			});
		}
	});

	//For TB, MTB
	document.querySelectorAll("input[data-points-field='true'], textarea[data-points-field='true']").forEach(function (el) {
		if (el.value.trim().length > 0) {
			totalpts += parseFloat(el.dataset.points) || 0;
		}

	});

	let totalFixed = totalpts.toFixed(1);
	document.querySelectorAll("#total_points").forEach(el => {
		el.textContent = totalFixed;
	});
	let hdnTotalPts = document.getElementById("hdn_total_points");
	if (hdnTotalPts) hdnTotalPts.value = totalFixed;
}