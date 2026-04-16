$.widget.bridge("uiAccordion", $.ui.accordion);
$(function () {
	$('input[type=text]').blur();

	$(".group-accordion-item").uiAccordion({
		icons: { "header": "ui-icon-circle-triangle-e", "activeHeader": "ui-icon-circle-triangle-s" },
		collapsible: true,
		active: 0,
		heightStyle: "content"
	});

	$('.group-accordion-item').find('.group-accordion-content').first().show();

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
			$("input[id$='_is_reviewer_only']").each(function () {
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
		if (radio) {
			$(this).prop("checked", false);
			$(this).trigger("change");
			if (typeof handleFollowUpVisibility === "function") handleFollowUpVisibility();
		}
	});

	reOrderIndex(false);
});

function reOrderIndex(onlyVisible = true) {
	var visibleFilter = (onlyVisible === true) ? ':visible' : '';
	var groupCounter = 0;
	var globalSortOrder = 0;
	var globalGroupSortOrder = 0;
	var ungropquestionCounter = 0;


	function processFollowUps($parentQ, parentIndex) {
		var isChoiceBased = $parentQ.children('table').find('> tbody > tr.choice-row').length > 0;
		var choiceIndexCounter = 0;

		$parentQ.children('table').find('> tbody > tr').each(function () {
			if ($(this).hasClass('choice-row')) {
				choiceIndexCounter++;
			} else if (!isChoiceBased && $(this).find("a[onclick*='addFollowUpQuestion']").length > 0) {
				choiceIndexCounter = 1;
			}

			if ($(this).hasClass('followup-inline-row')) {
				var $child = $(this).find('.surveyquestion.child-question' + visibleFilter).first();
				if ($child.length) {
					var currentIndex = choiceIndexCounter > 0 ? choiceIndexCounter : 1;
					globalSortOrder++;
					$child.children('table').find('td.indexNo .index-num').html('<b>' + parentIndex + '.' + currentIndex + '</b>');
					$child.children('table').find('.childIndexNo').html('<b>' + parentIndex + '.' + currentIndex + '</b>&nbsp;');
					$child.children('.question-sort-order').val(globalSortOrder);
					processFollowUps($child, parentIndex + '.' + currentIndex);
				}
			}
		});


		$parentQ.children('.follow-up-container').each(function (index) {
			var currentIndex = index + 1;
			var $child = $(this).find('.surveyquestion.child-question' + visibleFilter).first();
			if ($child.length) {
				globalSortOrder++;
				$child.children('table').find('td.indexNo .index-num').html('<b>' + parentIndex + '.' + currentIndex + '</b>');
				$child.children('table').find('.childIndexNo').html('<b>' + parentIndex + '.' + currentIndex + '</b>&nbsp;');
				$child.children('.question-sort-order').val(globalSortOrder);
				processFollowUps($child, parentIndex + '.' + currentIndex);
			}
		});
	}


	var containerSelector = (onlyVisible === true) ?
		'.group-accordion-item:visible, .group-ungrouped-questions:visible' :
		'.group-accordion-item, .group-ungrouped-questions';

	$(containerSelector).each(function () {
		globalGroupSortOrder++;
		$(this).children('.group-sort-order').val(globalGroupSortOrder);


		if ($(this).hasClass('group-accordion-item')) {
			groupCounter++;

			var $groupHeader = $(this).find('.group-accordion-header');
			var currentText = $groupHeader.text().trim();

			if (/^Group\s*[-]?\s*\d+$/i.test(currentText)) {
				var newText = currentText.replace(/Group\s*[-]?\s*\d+/i, 'Group-' + groupCounter);
				const $iconElem = $groupHeader.find('#group-name');
				if ($iconElem.length) {
					$iconElem.text(newText);
				}
			}

			var questionCounter = 0;
			var $groupContainer = $(this).find('.group-questions');
			if ($groupContainer.length) {
				$groupContainer.find('.surveyquestion:not(.child-question)' + visibleFilter).each(function () {
					questionCounter++;
					globalSortOrder++;
					var parentIndex = groupCounter + '.' + questionCounter;
					$(this).children('table').find('td.indexNo .index-num').html('<b>' + parentIndex + '.</b>');
					$(this).children('.question-sort-order').val(globalSortOrder);
					processFollowUps($(this), parentIndex);
				});
			}
		} else if ($(this).hasClass('group-ungrouped-questions')) {
			$(this).find('.surveyquestion:not(.child-question)' + visibleFilter).each(function () {
				ungropquestionCounter++;
				globalSortOrder++;
				var parentIndex = ungropquestionCounter;
				$(this).children('table').find('td.indexNo .index-num').html('<b>' + parentIndex + '.</b>');
				$(this).children('.question-sort-order').val(globalSortOrder);
				processFollowUps($(this), parentIndex);
			});
		}
	});


	$('.followup-linked-label').each(function () {
		var $label = $(this);
		var $container = $label.closest('tr');
		var qId = $container.find('.followup-val').val();
		var qTempId = $container.find("input[name*='[follow_up_temp_id]']").val();
		var $targetQ;

		if (qId) {
			$targetQ = $("input[name$='[id]'][value='" + qId + "']").filter(function () {
				return this.name.includes('[wk_survey_questions_attributes]') && !this.name.includes('[wk_survey_choices_attributes]');
			}).closest('.surveyquestion');
		} else if (qTempId) {
			$targetQ = $("input[name$='[temp_id]'][value='" + qTempId + "']").closest('.surveyquestion');
		}

		if ($targetQ && $targetQ.length > 0) {
			var $table = $targetQ.children('table');
			var indexNo = $table.find('.index-num').first().text() ||
				$table.find('.childIndexNo').first().text();

			if (indexNo) {
				indexNo = indexNo.trim();
				$label.html(FollowUpText + indexNo);
			}
		}
	});
}

function questionTypeChanged(dropdown) {
	const $select = $(dropdown);
	const value = $select.val();
	const $row = $select.closest("tr");
	const $table = $select.closest("table");
	const $choiceRows = $table.find("> tbody > tr.choice-row, > tbody > tr.choice-adder-row, > tr.choice-row, > tr.choice-adder-row");
	const $pointsCell = $row.find('.text-points');

	// Extract group and question indices from the select name
	const nameAttr = $select.attr("name");
	const match = nameAttr.match(/\[wk_survey_que_groups_attributes\]\[(\d+)\]\[wk_survey_questions_attributes\]\[(\d+)\]/);
	const groupIndex = match ? match[1] : "0";
	const questionIndex = match ? match[2] : "0";

	if (value === "RB" || value === "CB") {
		$table.find('> tbody > tr.tb-mtb-followup-adder-row, > tr.tb-mtb-followup-adder-row').hide();
		$choiceRows.show();
		$choiceRows.filter(".choice-row").each(function () {
			const choiceDestroy = this.querySelector("input[name*='[_destroy]']");
			if (choiceDestroy) {
				choiceDestroy.value = '0';
				if (choiceDestroy.type === 'checkbox') choiceDestroy.checked = false;
			}
		});
		const destroyField = $pointsCell.find("input[name*='[_destroy]']");
		if (destroyField.length > 0) {
			destroyField.first().val('1');
			destroyField.filter('[type="checkbox"]').prop('checked', true);
		}
		$pointsCell.css('display', 'none');
		if (typeof unlinkQuestion === "function") unlinkQuestion($pointsCell);

		if ($choiceRows.filter(".choice-row").length === 0) {
			const hasIndexCol = $row.closest('table').find('> tbody > tr:first-child > td.indexNo, > tr:first-child > td.indexNo').length > 0;
			const newRow = `
        <tr class="choice-row">
          ${hasIndexCol ? '<td></td>' : ''}
          <th align="left">Choice 1</th>
          <td align="left">
            <input type="hidden" name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][1][id]">
            <input size="40" maxlength="255" type="text"
                   name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][1][name]">
            <div style="text-align: right; width: 335px;">${addFollowupHtml}</div>
          </td>
          <td align="left">
            ${pointsText}&nbsp;<input size="5" maxlength="10" type="text"
                   name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][1][points]">
          </td>
        </tr>
      `;

			const newAdderRow = `
            <tr class="choice-adder-row">
                ${hasIndexCol ? '<td></td>' : ''}
                <td align="left" style="padding-top: 15px;">${addChoice}</td>
                <td></td>
                <td></td>
            </tr>
        `;
			const $newChoice = $(newRow);
			const $newAdder = $(newAdderRow);

			if ($table.children('tbody').length) {
				$table.children('tbody').append($newChoice);
			} else {
				$table.append($newChoice);
			}
			$newChoice.after($newAdder);

		}
	} else {
		$choiceRows.hide();
		$pointsCell.css('display', 'inline-block');
		let $tbMtbAdderRow = $table.find('> tbody > tr.tb-mtb-followup-adder-row, > tr.tb-mtb-followup-adder-row');
		$tbMtbAdderRow.show();
		if ($choiceRows.length) {
			$choiceRows.filter(".choice-row").each(function () {
				const destroyField = this.querySelector("input[name*='[_destroy]']");
				if (destroyField) {
					destroyField.value = '1';
					if (destroyField.type === 'checkbox') destroyField.checked = true;
				}
				this.style.display = 'none';
				if (typeof unlinkQuestion === "function") unlinkQuestion($(this));
			});
			const nextIndex = $choiceRows.length;
			const inputHtml = `
				<input type="hidden"
					name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][${nextIndex}][name]">
				${pointsText}&nbsp;<input type="text" size="5" maxlength="10"
					name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][${nextIndex}][points]">`;
			$pointsCell.html(inputHtml);
			let $followUpCell = $tbMtbAdderRow.find('.tb-mtb-followup-cell');
			if ($followUpCell.length > 0 && $followUpCell.find('a.icon-add').length === 0) {
				$followUpCell.html(addFollowupHtml);
			}
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

	const $table = $(table);
	const choiceRows = $table.find('> tbody > .choice-row, > tr.choice-row');
	const safeId = new Date().getTime() + Math.floor(Math.random() * 1000);

	const hasIndexCol = $table.find('> tbody > tr:first-child > td.indexNo, > tr:first-child > td.indexNo').length > 0;
	let templateLabel = 'Choice ';
	if (choiceRows.length > 0) {
		const firstTh = choiceRows.first().find('th').first();
		if (firstTh.length) {
			const textNode = firstTh.contents().filter(function () {
				return this.nodeType === 3 && $.trim(this.nodeValue) !== '';
			}).first();
			if (textNode.length) {
				const text = textNode.text().trim();
				if (text !== '') {
					templateLabel = text.replace(/\s*\d+$/, '') + ' ';
				}
			}
		}
	}
	const visibleIndex = choiceRows.filter(function () { return $(this).css('display') !== 'none'; }).length + 1;

	const newRow = document.createElement('tr');
	newRow.className = 'choice-row';
	newRow.innerHTML = `
    ${hasIndexCol ? '<td></td>' : ''}
		<th align="left" style="padding-top: 10px;">${templateLabel}${visibleIndex}</th>
    <td align="left">
      <input type="text" size="40" maxlength="255"
        name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][${safeId}][name]">
      <div style="text-align: right; margin-right: 12px;">${addFollowupHtml}</div>
		</td>
		<td align="left">
			${pointsText}&nbsp;<input type="text" size="5" maxlength="10"
        name="wksurvey[wk_survey_que_groups_attributes][${groupIndex}][wk_survey_questions_attributes][${questionIndex}][wk_survey_choices_attributes][${safeId}][points]">
				<a title="Delete" href="javascript:void(0);" onclick="DeleteChoice(this)" style="margin-left:5px;">` + delImg + `</a>
    </td>
  `;

	adderRow.parentNode.insertBefore(newRow, adderRow);
}

// Delete row
function DeleteChoice(link) {
	const row = link.closest("tr");
	const destroyField = row.querySelector("input[name*='[_destroy]']");
	if (destroyField) {
		destroyField.value = '1';
		if (destroyField.type === 'checkbox') destroyField.checked = true;
	}
	row.style.display = 'none';
	if (typeof unlinkQuestion === "function") unlinkQuestion($(row));
	if (typeof updateChoiceLabels === "function") updateChoiceLabels(row.closest("table"));
}

function DeleteGroup(element) {
	const container = element.closest('.group-accordion-item') || element.closest('.surveyquestion') || element.closest('tr');
	const destroyField = container.querySelector('input[name*="_destroy"]');
	if (destroyField) {
		destroyField.value = '1';
		if (destroyField.type === 'checkbox') destroyField.checked = true;
	}

	if (!confirm(deleteGrp)) return;

	if (destroyField) {
		destroyField.value = '1';
	}
	const $wrap = $(element).closest('.group-container-wrap');
	if ($wrap.length > 0) {
		$wrap.hide();
	} else {
		container.style.display = 'none';
	}
	if (typeof unlinkQuestion === "function") {
		$(container).find('.choice-row, .text-points').each(function () {
			unlinkQuestion($(this));
		});
	}
	reOrderIndex(false);
};

function DeleteQuestion(element) {
	const $el = $(element);
	const $question = $el.closest('.surveyquestion').length ? $el.closest('.surveyquestion') : $el.closest('tr');

	// For non-child questions, check group minimum
	if (!$question.hasClass('child-question')) {
		const $groupContainer = $el.closest('.group-ungrouped-questions');
		if ($groupContainer.length) {
			const hasGroupHeader = $groupContainer.find('.group-accordion-header').length > 0;
			const questionCount = $groupContainer.find('.surveyquestion:not(.child-question):visible').length;

			if (hasGroupHeader && questionCount <= 1) {
				alert(deleteGrpQuesWarning);
				return;
			}
		}
	}

	if (!confirm(deleteQues)) return;

	// If this is a follow-up (child) question, unlink it from its parent choice
	if ($question.hasClass('child-question')) {
		var questionId = $question.find("input[name$='[id]']").filter(function () {
			return this.name.includes('[wk_survey_questions_attributes]');
		}).first().val();
		var tempId = $question.find("input[name$='[temp_id]']").val();

		// Find all choices that link to this follow-up and clean up
		unlinkAllLinkersTo(questionId, tempId);
	}

	const $destroyField = $question.find('input[name*="_destroy"]');
	if ($destroyField.length) {
		$destroyField.val('1');
		$destroyField.filter('[type="checkbox"]').prop('checked', true);
	}

	// If nested inside a follow-up-container, hide the container and its wrapping tr
	var $container = $question.closest('.follow-up-container');
	if ($container.length) {
		var $inlineRow = $container.closest('tr.followup-inline-row');
		if ($inlineRow.length) {
			$inlineRow.hide();
		} else {
			$container.hide();
		}
	} else {
		$question.hide();
	}

	$question.find('.choice-row, .text-points').each(function () {
		unlinkQuestion($(this));
	});

	const $ungroupedBlock = $question.closest('.group-ungrouped-questions');
	if ($ungroupedBlock.length) {
		const visibleQuestions = $ungroupedBlock.find('.surveyquestion:visible');
		if (visibleQuestions.length === 0) {
			const $groupDestroy = $ungroupedBlock.find('.group-destroy-field');
			if ($groupDestroy.length) {
				$groupDestroy.val('1');
				$groupDestroy.filter('[type="checkbox"]').prop('checked', true);
			}
			$ungroupedBlock.closest('.group-container-wrap').hide();
		}
	}

	reOrderIndex();
}

function addUngroupedQues() {
	const template = document.getElementById('group_template');
	const clone = template.content.cloneNode(true);
	const $tempContainer = $('<div>').append(clone);
	$tempContainer.find('.group-actions, .group-accordion-header').remove();

	const $tempQues = $tempContainer.find('.surveyquestion');
	const $questionTemplate = $tempContainer.find('#question-template');
	const $addQuestionLink = $tempContainer.find('.add-question-link');

	let $lastNode = $('#group_template').prev();
	let $existingGroup = $lastNode.hasClass('group-ungrouped-questions') ? $lastNode : [];

	let newElem;

	if ($existingGroup.length > 0) {
		const $ungroupedSection = $existingGroup.find('.ungrouped-section');
		const groupNameCheck = $existingGroup.find('input[name*="[wk_survey_que_groups_attributes]"]').first().attr('name');
		const groupIndexMatch = groupNameCheck ? groupNameCheck.match(/\[wk_survey_que_groups_attributes\]\[(\d+)\]/) : null;
		const groupIndex = groupIndexMatch ? groupIndexMatch[1] : 2000;
		const questionIndex = $existingGroup.find('.surveyquestion').length;
		let html = $('<div>').append($tempQues.clone()).html();
		html = html.replace(/__GROUP_INDEX__/g, groupIndex)
			.replace(/__QUESTION_INDEX__/g, questionIndex);

		const $addLink = $ungroupedSection.find('.add-question-link');
		if ($addLink.length > 0) {
			$addLink.before(html);
		} else {
			$ungroupedSection.append(html);
		}
		newElem = $ungroupedSection.find('.surveyquestion').last();
	} else {
		const $unGroup = $('<div class="group-questions ungrouped-section">')
			.append($tempQues)
			.append($questionTemplate)
			.append($addQuestionLink.css('display', 'none'));
		const $unGroupQues = $('<div class="group-ungrouped-questions" style="margin-top: 10px;">').append($unGroup);

		$unGroupQues.prepend('<input type="hidden" name="wksurvey[wk_survey_que_groups_attributes][__GROUP_INDEX__][id]">');
		$unGroupQues.prepend('<input type="hidden" class="group-sort-order" name="wksurvey[wk_survey_que_groups_attributes][__GROUP_INDEX__][sort_order]">');
		$unGroupQues.prepend('<input type="hidden" class="group-destroy-field" name="wksurvey[wk_survey_que_groups_attributes][__GROUP_INDEX__][_destroy]" value="0">');

		const tableHtml = `
		<table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 5px;" class="group-container-wrap">
		  <tr>
			<td valign="top" width="25" style="padding-top: 5px;">
			  <div class="group-move-icons">
				<a href="javascript:void(0)" onclick="moveGroupUp(this)" title="Move Up" style="display:block;text-decoration:none; color:#016bff; margin-bottom: 4px;">
				  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: middle;">
						<path d="M12 19V5"></path><path d="M5 12l7-7 7 7"></path>
					</svg>
				</a>
				<a href="javascript:void(0)" onclick="moveGroupDown(this)" title="Move Down" style="display:block;text-decoration:none; color:#016bff;">
				  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: middle;">
						<path d="M12 5v14"></path><path d="M19 12l-7 7-7-7"></path>
					</svg>
				</a>
			  </div>
			</td>
			<td valign="top" class="td-ungrouped-wrap">
			</td>
		  </tr>
		</table>`;

		const $tempTable = $(tableHtml);
		$tempTable.find('.td-ungrouped-wrap').append($unGroupQues);

		const $temp = $('<div>').append($tempTable);

		let html = $temp.html();
		const groupIndex = new Date().getTime(); // ensure unique IDs
		html = html.replace(/__GROUP_INDEX__/g, groupIndex)
			.replace(/__QUESTION_INDEX__/g, 1);

		$("#group_template").before(html);
		newElem = $('.group-ungrouped-questions').last().find('.surveyquestion').last();
	}

	reOrderIndex(false);
	$('#review').trigger("change");
	return newElem;
}

// Add a new group dynamically
function addSurveyGroup() {
	const template = document.getElementById("group_template");

	const clone = template.content.cloneNode(true);
	const groupIndexNo = $(".group-accordion-item").length + 1;
	const groupIndex = new Date().getTime(); // ensure unique IDs for dynamically added groups

	let html = $('<div>').append(clone).html();
	html = html.replace(/__GROUP_INDEX__/g, groupIndex)
		.replace(/__QUESTION_INDEX__/g, new Date().getTime() + 1)
		.replace(/__GROUP_INDEX_NO__/g, groupIndexNo);

	$("#group_template").before(html);

	initializeGroupAccordion(groupIndex);
	reOrderIndex(false);
	$('#review').trigger('change');
}

function initializeGroupAccordion(groupIndex) {
	const $questionsAccordion = $("#group-" + groupIndex);
	$questionsAccordion.uiAccordion({
		icons: { "header": "ui-icon-circle-triangle-e", "activeHeader": "ui-icon-circle-triangle-s" },
		collapsible: true,
		active: 0,
		heightStyle: "content"
	});
}


function addQuestions(button) {
	const group = button.closest('.group-questions');
	if (!group) return null;
	const template = group.querySelector('#question-template');
	if (!template) return null;

	const clone = template.content.cloneNode(true);
	const wrapper = document.createElement('div');
	wrapper.appendChild(clone);

	const newId = new Date().getTime();
	let html = wrapper.innerHTML.replace(/NEW_RECORD/g, newId);

	const addLink = group.querySelector('.add-question-link');
	let newElem;
	if (addLink) {
		addLink.insertAdjacentHTML('beforebegin', html);
		newElem = $(addLink).prev('.surveyquestion');
	} else {
		group.insertAdjacentHTML('beforeend', html);
		newElem = $(group).find('.surveyquestion').last();
	}

	reOrderIndex(false);
	$('#review').trigger("change");
	return newElem;
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
		// Skip validation for questions inside hidden follow-up blocks
		var $block = $(this).closest('.survey-question-block');
		if ($block.length && !$block.is(':visible')) return true;

		switch (this.type) {
			case "radio":
				if (!$.isNumeric($("input[name='" + this.name + "']:checked").val())) {
					isUnAnswered = true;
					return false;
				}
				break;
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

/**
 * Show / hide follow-up question blocks based on the currently selected
 * Radio Button / Checkbox choices.
 */
function handleFollowUpVisibility() {
	var followupBlockIds = new Set();
	document.querySelectorAll("input[data-followup-block-id], textarea[data-followup-block-id]").forEach(function (el) {
		var fbid = el.getAttribute('data-followup-block-id');
		if (fbid) followupBlockIds.add(fbid);
	});

	var followupIds = new Set();
	document.querySelectorAll("input[data-followup-id], textarea[data-followup-id]").forEach(function (el) {
		var fid = el.getAttribute('data-followup-id');
		if (fid) followupIds.add(fid);
	});

	var allFollowupBlocks = new Set();
	followupBlockIds.forEach(id => allFollowupBlocks.add(id));
	followupIds.forEach(id => allFollowupBlocks.add('wkq_' + id));

	// 2. Determine which blocks should be visible based on current selected values
	var shouldBeVisible = new Set();

	var checkVisibleBlocks = function () {
		var changed = false;
		document.querySelectorAll("input[data-followup-id], textarea[data-followup-id]").forEach(function (el) {
			var isTriggering = false;
			if (el.type === 'radio' || el.type === 'checkbox') {
				isTriggering = el.checked;
			} else {
				isTriggering = el.value.trim() !== '';
			}

			if (isTriggering) {
				var parentBlock = el.closest('.survey-question-block');
				var pid = parentBlock ? parentBlock.id : null;
				// Parent block is considered visible if it's NOT a followup OR it's already approved to be visible
				var parentVisible = !pid || !allFollowupBlocks.has(pid) || shouldBeVisible.has(pid);

				if (parentVisible) {
					var fbid = el.getAttribute('data-followup-block-id');
					var fid = el.getAttribute('data-followup-id');
					var targetId = fbid ? fbid : ('wkq_' + fid);

					if (targetId && !shouldBeVisible.has(targetId)) {
						shouldBeVisible.add(targetId);
						changed = true;
					}
				}
			}
		});
		if (changed) {
			// Iterate again to cascade visibility down the hierarchy
			checkVisibleBlocks();
		}
	};
	checkVisibleBlocks();

	// 3. Apply visibility styles, avoiding redundant toggles which cause focus-loss
	allFollowupBlocks.forEach(function (id) {
		var block = document.getElementById(id);
		if (block) {
			if (shouldBeVisible.has(id)) {
				if (block.style.display === 'none') {
					block.style.display = '';
				}
			} else {
				if (block.style.display !== 'none') {
					block.style.display = 'none';

					// 5. Clear inputs for dynamically hidden follow-up blocks
					var radiosAndCheckboxes = block.querySelectorAll("input[type='radio'], input[type='checkbox']");
					radiosAndCheckboxes.forEach(function (input) {
						if (input.checked) {
							input.checked = false;
						}
					});
					var textInputs = block.querySelectorAll("input[type='text'], textarea");
					textInputs.forEach(function (input) {
						input.value = '';
					});
				}
			}
		}
	});

	// 4. Synchronize values between duplicate question instances
	$(".survey-question-block:visible").each(function () {
		var block = this;
		var qid = block.getAttribute('data-question-id');
		if (!qid) return;

		// Listen for changes to sync
		var inputs = block.querySelectorAll("input, textarea");
		inputs.forEach(function (input) {
			if (!input.dataset.syncBound) {
				input.addEventListener('change', function () {
					syncQuestionValues(qid, this);
				});
				input.dataset.syncBound = "true";
			}
		});
	});

	// 5. Hide empty fieldsets (e.g. groups that contain only hidden questions)
	document.querySelectorAll("fieldset.box.tabular").forEach(function (fieldset) {
		var allBlocks = fieldset.querySelectorAll(".survey-question-block");
		if (allBlocks.length > 0) {
			var anyVisible = false;
			allBlocks.forEach(function (block) {
				if (block.style.display !== 'none') {
					anyVisible = true;
				}
			});
			if (!anyVisible) {
				fieldset.style.display = 'none';
			} else {
				fieldset.style.display = '';
			}
		}
	});

	// 6. Update numbering to reflect visible questions only
	if (typeof reOrderIndex === "function") {
		reOrderIndex(true);
	}

	// 7. Update total points in case some inputs were cleared
	if (typeof updateTotalPoints === "function") {
		updateTotalPoints();
	}
}

// Initialise follow-up visibility on page load
$(function () {
	handleFollowUpVisibility();

});

function removeFollowUpLink(link) {
	if (!confirm("Are you sure you want to unlink this follow-up question?")) return;

	var $el = $(link);
	var $row = $el.closest('tr');
	var $parent = $el.parent();

	// 1. Clear linked ID fields in the whole row/container
	$row.find('.followup-val').val('');
	$row.find("input[name*='[follow_up_temp_id]'], input[name*='[follow_up_question_id]']").val('');

	// 2. UI Cleanup
	$row.find('.followup-linked-label').remove();
	$el.remove(); // Remove the "x" icon
	$row.find("a[onclick*='addFollowUpQuestion']").show();

	// 3. Hide inline row if it exists (for create-triggered inline questions)
	var $choiceTr = $row.hasClass('choice-row') ? $row : $row.closest('tr.choice-row');
	if ($choiceTr.length === 0) $choiceTr = $row.hasClass('tb-mtb-followup-adder-row') ? $row : $row.closest('tr.tb-mtb-followup-adder-row');

	if ($choiceTr.length > 0) {
		$choiceTr.next('.followup-inline-row').hide();
	}

	reOrderIndex(false);
}

function unlinkQuestion(choiceRow) {
	let followUpId = choiceRow.find('.followup-val').val();
	let followUpTempId = choiceRow.find("input[name*='[follow_up_temp_id]']").last().val();

	let questionToDelete = null;

	if (followUpId) {
		let qInputs = $("input[name$='[id]'][value='" + followUpId + "']").filter(function () {
			return this.name.includes('[wk_survey_questions_attributes]');
		});
		if (qInputs.length > 0) {
			questionToDelete = qInputs.closest('.surveyquestion');
		}
	} else if (followUpTempId) {
		let qInputs = $("input[name$='[temp_id]'][value='" + followUpTempId + "']");
		if (qInputs.length > 0) {
			questionToDelete = qInputs.closest('.surveyquestion');
		}
	}

	if (questionToDelete && questionToDelete.length > 0) {
		let isCanonicalParent = false;
		if (choiceRow.hasClass('choice-row')) {
			if (choiceRow.next('.followup-inline-row').find(questionToDelete).length > 0) {
				isCanonicalParent = true;
			}
		} else {
			// TB/MTB or other containers
			let $parentQ = choiceRow.closest('.surveyquestion');
			if ($parentQ.length > 0 && $.contains($parentQ[0], questionToDelete[0])) {
				// Only if it's not nested inside a choice-based inline row
				if (questionToDelete.closest('.followup-inline-row').length === 0) {
					isCanonicalParent = true;
				}
			}
		}

		if (isCanonicalParent) {
			// Find all other linkers and clear them first
			unlinkAllLinkersTo(followUpId, followUpTempId, choiceRow);

			const destroyField = questionToDelete.find('input[name*="_destroy"]');
			if (destroyField.length) {
				if (destroyField.is(':checkbox')) {
					destroyField.prop('checked', true);
				} else {
					destroyField.val('1');
				}
			} else {
				questionToDelete.remove();
			}

			questionToDelete.find('.choice-row, .text-points').each(function () {
				unlinkQuestion($(this));
			});

			// Hide the follow-up-container wrapper and its wrapping tr if nested
			var $container = questionToDelete.closest('.follow-up-container');
			if ($container.length) {
				var $inlineRow = $container.closest('tr.followup-inline-row');
				if ($inlineRow.length) {
					$inlineRow.hide();
				} else {
					$container.hide();
				}
			} else {
				questionToDelete.hide();
			}

			if (typeof reOrderIndex === "function") reOrderIndex(true);
		}
	}

	_clearFollowUpUI(choiceRow);
}

function _clearFollowUpUI($row) {
	$row.find('.followup-val').val('');
	$row.find("input[name*='[follow_up_temp_id]'], input[name*='[follow_up_question_id]']").val('');
	$row.find('.followup-linked-label, .icon-unlink').remove();
	$row.find("a[onclick*='addFollowUpQuestion']").show();

	var $choiceTr = $row.hasClass('choice-row') ? $row : $row.closest('tr.choice-row');
	if ($choiceTr.length > 0) {
		$choiceTr.next('.followup-inline-row').hide();
	}
}

function unlinkAllLinkersTo(id, tempId, exceptRow = null) {
	if (id) {
		$('.followup-val[value="' + id + '"]').each(function () {
			var $choiceRow = $(this).closest('tr.choice-row, .tb-mtb-followup-cell, .text-points');
			if (!exceptRow || !$choiceRow.is(exceptRow)) {
				_clearFollowUpUI($choiceRow);
			}
		});
	}
	if (tempId) {
		$("input[name*='[follow_up_temp_id]'][value='" + tempId + "']").each(function () {
			var $choiceRow = $(this).closest('tr.choice-row, .tb-mtb-followup-cell, .text-points');
			if (!exceptRow || !$choiceRow.is(exceptRow)) {
				_clearFollowUpUI($choiceRow);
			}
		});
	}
}

function addFollowUpQuestion(link) {
	var existingQuestions = [];
	var seenIds = new Set();
	var $currentQuestion = $(link).closest('.surveyquestion');

	$('.surveyquestion.child-question:visible').each(function () {
		var $q = $(this);
		if ($q.is($currentQuestion)) return;

		// Exclude ancestors to prevent circular references
		if ($.contains($q[0], $currentQuestion[0])) return;

		// Extract IDs from the question's own fields
		var qId = $q.find("> input[name*='[wk_survey_questions_attributes]'][name$='[id]']").val() ||
			$q.find("input[name*='[wk_survey_questions_attributes]'][name$='[id]']").first().val();
		var qTempId = $q.find("> input[name*='[temp_id]']").val() ||
			$q.find("input[name*='[temp_id]']").first().val();

		if (!qId && !qTempId) return;

		var key = qId || qTempId;
		if (seenIds.has(key)) return;
		seenIds.add(key);

		var $nameInput = $q.find("input[name*='[name]']").first();
		var qName = $nameInput.val();
		var qIndex = ($q.find('.index-num').first().text() || $q.find('.childIndexNo').first().text()).trim();

		if (qName) qName = qName.trim();

		existingQuestions.push({ id: qId, tempId: qTempId, name: qName, index: qIndex });
	});


	var existingSelectHtml = '';
	if (existingQuestions.length > 0) {
		var opts = existingQuestions.map(function (q) {
			var displayName = q.index + (q.name ? ' ' + q.name : ' Question');
			return '<option value="' + (q.id || q.tempId) + '" data-is-temp="' + (!q.id) + '" data-index="' + q.index + '">' +
				$('<div>').text(displayName).html() + '</option>';
		}).join('');
		existingSelectHtml = '<div id="followup-existing-select-wrap" style="margin-top:8px;display:none;">' +
			'<label style="font-weight:bold;display:block;margin-bottom:4px;">Select question:</label>' +
			'<select id="followup-existing-select" style="width:100%;max-width:380px;">' +
			opts +
			'</select>' +
			'</div>';
	} else {
		existingSelectHtml = '<div id="followup-existing-select-wrap" style="margin-top: 20px;margin-bottom: 12px;display:none;">' +
			'<em style="color:#856404;background: #fff3cd;padding: 6px 10px;">No followup questions available to link.</em>' +
			'</div>';
	}

	var dialogHtml = `
		<div>
			<label style="display:block;margin-bottom:6px;">
				<input type="radio" name="followup_mode" value="create" checked>
				${AddFollowUpText}
			</label>
			<label style="display:block;">
				<input type="radio" name="followup_mode" value="existing">
				${LinkFollowUpText}
			</label>
    	${existingSelectHtml}
		</div>
	`;

	var $dlg = $('<div title="' + FollowUpLinkText + '">' + dialogHtml + '</div>');

	$dlg.on('change', 'input[name="followup_mode"]', function () {
		if ($(this).val() === 'existing') {
			$dlg.find('#followup-existing-select-wrap').show();
		} else {
			$dlg.find('#followup-existing-select-wrap').hide();
		}
	});

	$dlg.dialog({
		autoOpen: true,
		modal: true,
		resizable: false,
		width: 440,
		buttons: [
			{
				text: 'OK',
				click: function () {
					var mode = $dlg.find('input[name="followup_mode"]:checked').val();
					$dlg.dialog('close');
					$dlg.remove();

					if (mode === 'existing') {
						if (existingQuestions.length === 0) {
							alert('No followup questions are available to link.');
							return;
						}
						var $sel = $dlg.find('#followup-existing-select option:selected');
						var targetId = $sel.val();
						var isTemp = $sel.attr('data-is-temp') === 'true';
						var indexNo = $sel.attr('data-index');

						_doLinkExistingFollowUp(link, targetId, isTemp, indexNo);
					} else {
						_doCreateFollowUp(link);
					}
				}
			},
			{
				text: 'Cancel',
				click: function () {
					$dlg.dialog('close');
					$dlg.remove();
				}
			}
		]
	});
}

function _doCreateFollowUp(link) {
	let contextRow = $(link).closest('tr.choice-row');
	if (contextRow.length === 0) contextRow = $(link).closest('.tb-mtb-followup-cell');
	if (contextRow.length === 0) contextRow = $(link).closest('.text-points');

	let qInput = contextRow.find("input[name*='[wk_survey_'").first();

	if (qInput.length === 0 && contextRow.hasClass('tb-mtb-followup-cell')) {
		let $table = contextRow.closest('table');
		qInput = $table.find('.text-points input[name*="[wk_survey_"]').first();
	}

	const nameAttr = qInput.attr('name');
	if (!nameAttr) return;

	let groupContainer = contextRow.closest('.group-questions');
	if (groupContainer.length === 0) groupContainer = contextRow.closest('.ungrouped-section');

	let newQuestion;
	if (groupContainer.length > 0) {
		let addBtn = groupContainer.find('.add-question-link a.icon-add');
		if (addBtn.length > 0) {
			newQuestion = addQuestions(addBtn[0]);
		} else {
			newQuestion = addUngroupedQues();
		}
	} else {
		let addBtn = $('a[onclick*="addUngroupedQues"]');
		if (addBtn.length > 0) {
			newQuestion = addUngroupedQues();
		}
	}

	if (!newQuestion || newQuestion.length === 0) return;

	newQuestion.addClass('child-question');
	newQuestion.find('a[title="Move Up"], a[title="Move Down"]').hide();

	const tempId = 'tmp_' + new Date().getTime() + Math.floor(Math.random() * 1000);

	const qInputNew = newQuestion.find("input[name*='[wk_survey_questions_attributes]']").first();
	const qName = qInputNew.attr('name');

	let tempInputPath = qName.replace(/\[(name|id|sort_order|question_type)\]$/, '[temp_id]');
	if (tempInputPath === qName) {
		tempInputPath = qName.substring(0, qName.lastIndexOf('[')) + '[temp_id]';
	}

	newQuestion.append(`<input type="hidden" name="${tempInputPath}" value="${tempId}">`);

	const choiceName = contextRow.hasClass('choice-row')
		? (contextRow.find("input[name*='[name]']").val() || 'followup')
		: 'followup';

	let choiceTempPath = nameAttr.replace(/\[(name|id|points|is_answer)\]$/, '[follow_up_temp_id]');
	if (choiceTempPath === nameAttr) choiceTempPath = nameAttr.substring(0, nameAttr.lastIndexOf('[')) + '[follow_up_temp_id]';

	const $row = $(link).closest('tr');
	const $target = $(link).parent();
	$row.find("input[name*='[follow_up_temp_id]']").remove();
	$target.append(`<input type="hidden" class="followup-val" name="${choiceTempPath}" value="${tempId}">`);

	if (newQuestion.is('fieldset')) {
		var $div = $('<div>');
		$.each(newQuestion[0].attributes, function () {
			if (this.specified) $div.attr(this.name, this.value);
		});
		$div.append(newQuestion.contents());
		$div.append('<hr style="height: 1px; background-color: #696969; box-shadow: 0 1px 2px rgba(0,0,0,0.06); margin: 8px 0;">');

		$div.find('> table > tbody > tr, > table > tr').each(function () {
			$(this).children('td, th').first().remove();
		});
		$div.find('.childIndexNo').show();

		newQuestion.replaceWith($div);
		newQuestion = $div;
	}

	let $choiceTr = contextRow.hasClass('choice-row') ? contextRow : contextRow.closest('tr');
	if ($choiceTr.length > 0) {
		let $followUpTr = $('<tr class="followup-inline-row"></tr>');
		let hasIndexLayout = contextRow.closest('table').find('> tbody > tr:first-child > td.indexNo, > tr:first-child > td.indexNo').length > 0;
		let indentCols = hasIndexLayout ? '<td></td><td></td>' : '<td></td>';
		$followUpTr.append(indentCols);
		let $td = $('<td colspan="4" style="padding: 0;"></td>');
		let $container = $('<div class="follow-up-container" data-choice-name="' + choiceName + '"></div>');
		$container.append(newQuestion);
		$td.append($container);
		$followUpTr.append($td);
		$choiceTr.after($followUpTr);
	} else {
		let parentQuestion = $(link).closest('.surveyquestion');
		if (parentQuestion.length > 0) {
			let $container = $('<div class="follow-up-container" data-choice-name="' + choiceName + '"></div>');
			$container.append(newQuestion);
			parentQuestion.append($container);
		}
	}

	$(link).parent().find('.followup-linked-label, .icon-unlink').remove();

	reOrderIndex(false);
	$(link).hide();

	$('html, body').animate({
		scrollTop: newQuestion.offset().top - 100
	}, 500);
}

function _doLinkExistingFollowUp(link, targetId, isTemp, indexNo) {
	let contextRow = $(link).closest('tr.choice-row');
	if (contextRow.length === 0) contextRow = $(link).closest('.tb-mtb-followup-cell');
	if (contextRow.length === 0) contextRow = $(link).closest('.text-points');

	let qInput = contextRow.find("input[name*='[wk_survey_'").first();
	if (qInput.length === 0 && contextRow.hasClass('tb-mtb-followup-cell')) {
		let $table = contextRow.closest('table');
		qInput = $table.find('.text-points input[name*="[wk_survey_"]').first();
	}

	const nameAttr = qInput.attr('name');
	if (!nameAttr) return;

	const $row = $(link).closest('tr');
	const $target = $(link).parent();

	$row.find("input[name*='[follow_up_question_id]'], input[name*='[follow_up_temp_id]']").remove();

	if (isTemp) {
		let choiceTempPath = nameAttr.replace(/\[(name|id|points|is_answer)\]$/, '[follow_up_temp_id]');
		if (choiceTempPath === nameAttr) {
			choiceTempPath = nameAttr.substring(0, nameAttr.lastIndexOf('[')) + '[follow_up_temp_id]';
		}
		$target.append(
			`<input type="hidden" name="${choiceTempPath}" value="${targetId}">`
		);
	} else {
		let followupIdPath = nameAttr.replace(/\[(name|id|points|is_answer)\]$/, '[follow_up_question_id]');
		if (followupIdPath === nameAttr) {
			followupIdPath = nameAttr.substring(0, nameAttr.lastIndexOf('[')) + '[follow_up_question_id]';
		}
		$target.append(
			`<input type="hidden" class="followup-val" name="${followupIdPath}" value="${targetId}">`
		);
	}

	$row.find('.followup-linked-label, .icon-unlink').remove();
	$target.append(
		`<span class="followup-linked-label" style="color:#016bff;margin-left:4px;font-weight: normal;">` +
		`${FollowUpText} ${indexNo}</span>` + unlinkFollowupHtml
	);

	$(link).hide();
	reOrderIndex(false);
}

function getChildQuestions($question) {
	var children = [];
	$question.find('.follow-up-container').each(function () {
		var $child = $(this).find('.surveyquestion.child-question');
		$child.each(function () {
			children.push(this);
			children = children.concat(getChildQuestions($(this)));
		});
	});

	children = children.filter(function (item, pos) { return children.indexOf(item) === pos; });

	return children;
}

function moveQuestionUp(btn) {
	var $question = $(btn).closest('.surveyquestion:not(.child-question)');
	var $prev = $question.prevAll('.surveyquestion:not(.child-question):not(:hidden)[style!="display: none;"]').first();

	// If no visible prev question, fall back to any prev question
	if ($prev.length === 0) {
		$prev = $question.prevAll('.surveyquestion:not(.child-question)').first();
	}

	if ($prev.length > 0) {
		// Children are nested inside the parent, so they move automatically
		$question.insertBefore($prev);
		reOrderIndex(false);
	}
}

function moveQuestionDown(btn) {
	var $question = $(btn).closest('.surveyquestion:not(.child-question)');
	var $next = $question.nextAll('.surveyquestion:not(.child-question):not(:hidden)[style!="display: none;"]').first();

	// If no visible next question, fall back to any next question
	if ($next.length === 0) {
		$next = $question.nextAll('.surveyquestion:not(.child-question)').first();
	}

	if ($next.length > 0) {
		// Children are nested inside the parent, so they move automatically
		$question.insertAfter($next);
		reOrderIndex(false);
	}
}

function moveGroupUp(btn) {
	var $group = $(btn).closest('.group-container-wrap');
	var $prev = $group.prevAll('.group-container-wrap:visible').first();

	if ($prev.length === 0) {
		$prev = $group.prevAll('.group-container-wrap').first();
	}

	if ($prev.length > 0) {
		$group.insertBefore($prev);
		reOrderIndex(false);
	}
}

function moveGroupDown(btn) {
	var $group = $(btn).closest('.group-container-wrap');
	var $next = $group.nextAll('.group-container-wrap:visible').first();

	if ($next.length === 0) {
		$next = $group.nextAll('.group-container-wrap').first();
	}

	if ($next.length > 0) {
		$group.insertAfter($next);
		reOrderIndex(false);
	}
}

function updateChoiceLabels(tableElement) {
	const $table = $(tableElement);
	let templateLabel = 'Choice ';
	const visibleRows = $table.find('> tbody > .choice-row, > tr.choice-row').filter(function () {
		return $(this).css('display') !== 'none';
	});
	visibleRows.each(function (index) {
		const $th = $(this).find('th').first();
		if ($th.length) {
			let textNode = $th.contents().filter(function () {
				return this.nodeType === 3 && $.trim(this.nodeValue) !== '';
			}).first();

			let currentText = textNode.length ? textNode.text().trim() : '';

			if (index === 0 && currentText !== '') {
				templateLabel = currentText.replace(/\s*\d+$/, '') + ' ';
			}

			let newText = templateLabel + (index + 1);
			if (textNode.length) {
				textNode[0].nodeValue = newText;
			} else {
				$th.prepend(document.createTextNode(newText));
			}
		}
	});
}

function syncQuestionValues(qid, triggerItem) {
	if (window._isSyncing) return;
	window._isSyncing = true;
	try {
		// Find all blocks with the same question ID
		document.querySelectorAll('.survey-question-block[data-question-id="' + qid + '"]').forEach(function (block) {
			if (block.contains(triggerItem)) return; // Skip the block that triggered the sync

			// Sync inputs
			if (triggerItem.type === 'radio') {
				var selectedChoiceId = triggerItem.value;
				var radios = block.querySelectorAll('input[type="radio"]');
				radios.forEach(function (r) {
					if (r.value === selectedChoiceId) {
						r.checked = triggerItem.checked;
					}
				});
			} else if (triggerItem.type === 'checkbox') {
				// For checkboxes, match by name suffix (choice ID part)
				var nameParts = triggerItem.name.split('_');
				var choiceIdPart = nameParts[nameParts.length - 1];
				var checkbox = block.querySelector('input[type="checkbox"][name$="_' + choiceIdPart + '"]');
				if (checkbox) {
					checkbox.checked = triggerItem.checked;
				}
			} else {
				// Text inputs
				var textInput = block.querySelector('input[type="text"], textarea');
				if (textInput) {
					textInput.value = triggerItem.value;
				}
			}
		});
		// Trigger points update
		if (typeof updateTotalPoints === "function") updateTotalPoints();
		// Trigger followup visibility (in case one of the synced items triggers another followup)
		if (typeof handleFollowUpVisibility === "function") handleFollowUpVisibility();
	} finally {
		window._isSyncing = false;
	}
}