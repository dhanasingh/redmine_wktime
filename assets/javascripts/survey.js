$.widget.bridge("uiAccordion", $.ui.accordion);
$(function () {
	$('input[type=text]').blur();

	$(".group-accordion-item").uiAccordion({
		icons: { "header": "ui-icon-triangle-1-e", "activeHeader": "ui-icon-triangle-1-s" },
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

	setTimeout(function () {
    refreshSurveySidebar();
	}, 500);


	$('#survey_form').on('submit', function() {
		var $allChoiceInputs = $(this).find('input[name*="[wk_survey_choices_attributes]"], select[name*="[wk_survey_choices_attributes]"]');
		var groups = {};
		$allChoiceInputs.each(function() {
			var n = this.name || '';
			var m = n.match(/^(.*\[wk_survey_choices_attributes\]\[[^\]]+\])\[([^\]]+)\]$/);
			if (!m) return;
			var base = m[1], field = m[2];
			if (!groups[base]) groups[base] = { inputs: [], fields: {} };
			groups[base].inputs.push(this);
			groups[base].fields[field] = (this.value || '').trim();
		});
		Object.keys(groups).forEach(function(base) {
			var g = groups[base];
			var hasId   = ('id' in g.fields)   && g.fields.id   !== '';
			var hasName = ('name' in g.fields)  && g.fields.name !== '';
			if (!hasId && !hasName) {
				// TB/MTB choices intentionally have empty id and name — check the parent question type
				// before disabling, so their points slot is preserved.
				var $qrow = $(g.inputs[0]).closest('.surveyquestion, .qrow');
				var isTbMtb = $qrow.hasClass('ed-qtype-TB') || $qrow.hasClass('ed-qtype-MTB');
				if (!isTbMtb) {
					g.inputs.forEach(function(inp) { inp.disabled = true; });
				}
			}
		});
	});
});


function refreshSurveySidebar(activeGroupId) {
	const accordion = $('#survey-sidebar-accordion');
	if (accordion.length === 0) return;

	const preservedActiveGroupId = activeGroupId ||
		accordion.find('> h3.ui-accordion-header-active').attr('data-sidebar-group-target') ||
		accordion.find('> h3[aria-selected="true"]').attr('data-sidebar-group-target');

	if (accordion.hasClass('ui-accordion')) accordion.uiAccordion('destroy');
	accordion.empty();

	let sidebarGroupCounter = 0;
	let globalUngroupedCounter = 0;

	$('.group-container-wrap').each(function() {
		const groupWrap = $(this);

		// Use own-display only (NOT :hidden) — :hidden also matches collapsed accordion panels
		if (groupWrap[0].style.display === 'none') return;
		const groupDestroyVal = groupWrap.find('.group-destroy-field, input[name*="[wk_survey_que_groups_attributes]"][name*="[_destroy]"]').first().val();
		if (groupDestroyVal === '1') return;

		const isGrouped = groupWrap.find('.group-accordion-item').length > 0;
		if (isGrouped) sidebarGroupCounter++;

		let sidebarGroupId = groupWrap.attr('data-sidebar-group-id');
		if (!sidebarGroupId) {
			sidebarGroupId = 'sidebar-group-' + Date.now() + '-' + Math.floor(Math.random() * 100000);
			groupWrap.attr('data-sidebar-group-id', sidebarGroupId);
		}

		let groupName = 'Untitled Group';
		const groupInput = groupWrap.find('.group-name-hidden, .group-name-input').first();
		if (groupInput.length > 0) {
			const value = groupInput.is('[contenteditable]') ? groupInput.text() : groupInput.val();
			if (value && value.trim() !== '') groupName = value.trim();
		}

		if (isGrouped) {
			accordion.append(`
				<h3 class="sidebar-sortable-group" data-sidebar-group-target="${sidebarGroupId}">
					<span class="sidebar-drag-handle group-drag-handle">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none">
							<circle cx="6" cy="6" r="1.5" fill="currentColor"/>
							<circle cx="12" cy="6" r="1.5" fill="currentColor"/>
							<circle cx="18" cy="6" r="1.5" fill="currentColor"/>
							<circle cx="6" cy="12" r="1.5" fill="currentColor"/>
							<circle cx="12" cy="12" r="1.5" fill="currentColor"/>
							<circle cx="18" cy="12" r="1.5" fill="currentColor"/>
							<circle cx="6" cy="18" r="1.5" fill="currentColor"/>
							<circle cx="12" cy="18" r="1.5" fill="currentColor"/>
							<circle cx="18" cy="18" r="1.5" fill="currentColor"/>
						</svg>
					</span>
					${groupName}
				</h3>
			`);
		}

		const content = $('<div></div>');
		let topLevelCount = 0;
		const parentTopLevelNo = {};

		groupWrap.find('.surveyquestion').each(function() {
			const question = $(this);

			// Check own display only — :hidden also matches collapsed accordion panels
			if (this.style.display === 'none') return;
			const qDestroy = question.find('> input[name*="_destroy"]').val();
			if (qDestroy === '1') return;
			if (question.closest('.follow-up-container, .followup-inline-row').filter(function() { return this.style.display === 'none'; }).length) return;

			let sidebarQuestionId = question.attr('data-sidebar-question-id');
			if (!sidebarQuestionId) {
				sidebarQuestionId = 'sidebar-question-' + Date.now() + '-' + Math.floor(Math.random() * 100000);
				question.attr('data-sidebar-question-id', sidebarQuestionId);
			}

			let questionText = 'Untitled Question';
			const questionInput = question.find('.question-name-input').first();
			if (questionInput.length > 0) {
				const value = questionInput.val();
				if (value && value.trim() !== '') questionText = value.trim();
			}

			let questionNo = '';
			const isChildQ = question.hasClass('child-question');

			if (isChildQ) {
				function _getChoiceIdx($inlineRow) {
					var $container = $inlineRow.closest('.choices, .tb-mtb-followup-adder-row');
					var idx = 0;
					$container.find('> .choice, > .followup-inline-row').each(function() {
						if ($(this).hasClass('choice') && this.style.display !== 'none') {
							idx++;
						} else if ($(this).is($inlineRow)) {
							return false;
						}
					});
					return idx > 0 ? idx : 1;
				}

				var suffixes = [];
				var $cursor = question.closest('.followup-inline-row');
				while ($cursor.length) {
					suffixes.unshift(_getChoiceIdx($cursor));
					var $parentSurveyQ = $cursor.closest('.surveyquestion');
					$cursor = $parentSurveyQ.closest('.followup-inline-row');
				}

				var $rootQ = question;
				var $walkUp = question.closest('.followup-inline-row');
				while ($walkUp.length) {
					$rootQ = $walkUp.closest('.surveyquestion');
					$walkUp = $rootQ.closest('.followup-inline-row');
				}
				var rootKey = $rootQ.attr('data-sidebar-question-id') || $rootQ.attr('id') || 'unk';
				var rootNo = parentTopLevelNo[rootKey] || (isGrouped ? sidebarGroupCounter + '.' + topLevelCount : String(topLevelCount));
				questionNo = rootNo + '.' + suffixes.join('.');
			} else {
				topLevelCount++;
				if (isGrouped) {
					questionNo = sidebarGroupCounter + '.' + topLevelCount;
				} else {
					globalUngroupedCounter++;
					questionNo = globalUngroupedCounter;
				}
				parentTopLevelNo[sidebarQuestionId] = String(questionNo);
			}

			const isChildQuestion = question.hasClass('child-question');
			const questionHtml = $(`
				<div class="sidebar-question ${isChildQuestion ? 'sidebar-child-question' : ''}" data-sidebar-target="${sidebarQuestionId}">
					${!isChildQuestion ? `
					<span class="sidebar-drag-handle question-drag-handle" title="Drag to reorder question">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none">
							<circle cx="6" cy="6" r="1.5" fill="currentColor"/>
							<circle cx="12" cy="6" r="1.5" fill="currentColor"/>
							<circle cx="18" cy="6" r="1.5" fill="currentColor"/>
							<circle cx="6" cy="12" r="1.5" fill="currentColor"/>
							<circle cx="12" cy="12" r="1.5" fill="currentColor"/>
							<circle cx="18" cy="12" r="1.5" fill="currentColor"/>
							<circle cx="6" cy="18" r="1.5" fill="currentColor"/>
							<circle cx="12" cy="18" r="1.5" fill="currentColor"/>
							<circle cx="18" cy="18" r="1.5" fill="currentColor"/>
						</svg>
					</span>
					` : ''}
					<span class="sidebar-q-num">${questionNo}</span><span class="sidebar-q-text">${questionText}</span>
				</div>
			`);

			content.append(questionHtml);
		});

		if (isGrouped) {
			accordion.append(content);
		} else {
			content.children().each(function() { accordion.append(this); });
		}
	});

	let activeIndex = 0;
	if (preservedActiveGroupId) {
		accordion.find('> h3').each(function(index) {
			if ($(this).attr('data-sidebar-group-target') === preservedActiveGroupId) {
				activeIndex = index;
				return false;
			}
		});
	}

	accordion.uiAccordion({ collapsible: true, heightStyle: 'content', active: activeIndex, header: '> h3' });
	initializeSidebarGroupSortable();
	initializeSidebarQuestionSortable();
}

function initializeSidebarGroupSortable() {
	const accordion = $('#survey-sidebar-accordion');
	if (accordion.length === 0) return;

	if (accordion.hasClass('ui-sortable')) accordion.sortable('destroy');

	accordion.sortable({
		items: '> h3, > .sidebar-question:not(.sidebar-child-question)',
		axis: 'y',
		tolerance: 'pointer',
		cursor: 'move',
		placeholder: 'sidebar-group-placeholder',
		handle: '.group-drag-handle, .question-drag-handle',
		start: function() { accordion.data('sidebar-sort-changed', false); },
		update: function() { accordion.data('sidebar-sort-changed', true); },
		stop: function() {
			if (accordion.data('sidebar-sort-changed')) syncSidebarTopLevelOrder();
		}
	});
}

function syncSidebarTopLevelOrder() {
	const accordion = $('#survey-sidebar-accordion');
	if (accordion.length === 0) return;

	const orderedWraps = [];
	accordion.children('h3, .sidebar-question').each(function() {
		const $el = $(this);
		if ($el.hasClass('sidebar-child-question')) return;
		let $wrap = $();
		if ($el.is('h3')) {
			const gid = $el.attr('data-sidebar-group-target');
			if (gid) $wrap = $('[data-sidebar-group-id="' + gid + '"]');
		} else {
			const qid = $el.attr('data-sidebar-target');
			if (qid) {
				const $realQ = $('[data-sidebar-question-id="' + qid + '"]');
				$wrap = $realQ.closest('.group-container-wrap');
			}
		}
		if ($wrap.length) orderedWraps.push($wrap[0]);
	});

	if (orderedWraps.length === 0) return;

	const anchor = document.getElementById('group_template');
	const parent = anchor ? anchor.parentNode : orderedWraps[0].parentNode;
	orderedWraps.forEach(function(wrap) {
		if (anchor) parent.insertBefore(wrap, anchor);
		else        parent.appendChild(wrap);
	});

	reOrderIndex(false);
	refreshSurveySidebar();
}

function initializeSidebarQuestionSortable() {
	$('#survey-sidebar-accordion .ui-accordion-content').each(function() {
		const questionPanel = $(this);

		if (questionPanel.hasClass('ui-sortable')) questionPanel.sortable('destroy');

		questionPanel.sortable({
			items: '> .sidebar-question:not(.sidebar-child-question)',
			axis: 'y',
			tolerance: 'pointer',
			cursor: 'move',
			placeholder: 'ui-sortable-placeholder',
			handle: '.question-drag-handle',
			start: function() { questionPanel.data('sidebar-sort-changed', false); },
			update: function() { questionPanel.data('sidebar-sort-changed', true); },
			stop: function() {
				if (questionPanel.data('sidebar-sort-changed')) syncSidebarQuestionOrder(questionPanel);
			}
		});
	});
}

function syncSidebarQuestionOrder(questionPanel) {
	const orderedQuestionIds = [];
	questionPanel.find('> .sidebar-question:not(.sidebar-child-question)').each(function() {
		const questionId = $(this).attr('data-sidebar-target');
		if (questionId) orderedQuestionIds.push(questionId);
	});

	const groupId = questionPanel.prev('h3').attr('data-sidebar-group-target');
	if (!groupId) return;

	const realGroup = $('[data-sidebar-group-id="' + groupId + '"]');
	if (realGroup.length === 0) return;

	const realQuestionContainer = realGroup.find('.group-questions').first();
	if (realQuestionContainer.length === 0) return;

	orderedQuestionIds.forEach(function(questionId, index) {
		const realQuestion = $('[data-sidebar-question-id="' + questionId + '"]');
		if (realQuestion.length === 0) return;

		if (index === 0) {
			realQuestion.prependTo(realQuestionContainer);
		} else {
			const prevRealQuestion = $('[data-sidebar-question-id="' + orderedQuestionIds[index - 1] + '"]');
			if (prevRealQuestion.length > 0) realQuestion.insertAfter(prevRealQuestion);
		}
	});

	reOrderIndex(false);
	refreshSurveySidebar(groupId);
}

function syncSidebarGroupOrder() {
	const accordion = $('#survey-sidebar-accordion');
	if (accordion.length === 0) return;

	const orderedGroupIds = [];
	accordion.find('> h3').each(function() {
		const id = $(this).attr('data-sidebar-group-target');
		if (id) orderedGroupIds.push(id);
	});

	if (orderedGroupIds.length === 0) return;

	orderedGroupIds.forEach(function(groupId) {
		const realGroup = $('[data-sidebar-group-id="' + groupId + '"]');
		if (realGroup.length === 0) return;
		// Insert before the template so new groups always append after existing ones
		$('#group_template').before(realGroup);
	});

	reOrderIndex(false);
	refreshSurveySidebar();
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
	// Rebuild the outline / sidebar so the deleted group (and all its
	// questions and follow-ups) disappear from the table-of-contents
	// without requiring a page reload.
	if (typeof refreshSurveySidebar === "function") refreshSurveySidebar();
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
	} else {
		// New (unsaved) question – remove from DOM entirely
		var $container = $question.closest('.follow-up-container');
		if ($container.length) {
			var $inlineRow = $container.closest('tr.followup-inline-row');
			if ($inlineRow.length) {
				$inlineRow.remove();
			} else {
				$container.remove();
			}
		} else {
			$question.remove();
		}
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

	reOrderIndex(false);
	refreshSurveySidebar();
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

	refreshSurveySidebar();

	$('#review').trigger("change");

	// Scroll to newly added question
	scrollToNewElement(newElem[0]);
	return newElem;
}

// Scroll to newly added element
function scrollToNewElement(element) {
	if (element) {
		setTimeout(function() {
			element.scrollIntoView({ behavior: 'smooth', block: 'start' });
		}, 100);
	}
}

// Add a new group dynamically
function addSurveyGroup() {
	const template = document.getElementById("group_template");

	const clone = template.content.cloneNode(true);
	// Count only LIVE groups — skip soft-deleted ones. A deleted group has:
	//   (a) its wrapping .group-container-wrap hidden (DeleteGroup hides the
	//       table wrapper, NOT the .group-accordion-item itself), and/or
	//   (b) a descendant hidden _destroy input whose name targets
	//       [wk_survey_que_groups_attributes][N][_destroy] set to "1".
	function _isGroupRemoved($g){
		var $wrap = $g.closest(".group-container-wrap");
		if ($wrap.length && $wrap[0].style.display === "none") return true;
		if ($g[0].style.display === "none") return true;
		var $d = $g.find("input[name*='[wk_survey_que_groups_attributes]'][name$='[_destroy]']").first();
		if ($d.length && ($d.val() === "1" || $d.prop("checked"))) return true;
		return false;
	}
	const liveGroups = $(".group-accordion-item").filter(function () {
		return !_isGroupRemoved($(this));
	});
	const groupIndexNo = liveGroups.length + 1;
	const groupIndex = new Date().getTime(); // ensure unique IDs for dynamically added groups

	let html = $('<div>').append(clone).html();
	// A new group always starts with its first question (visible badge = "<n>.1").
	// The placeholder is just for display; reOrderIndex(true) will rewrite it.
	html = html.replace(/__GROUP_INDEX__/g, groupIndex)
		.replace(/__QUESTION_INDEX__/g, 1)
		.replace(/__GROUP_INDEX_NO__/g, groupIndexNo);

	$("#group_template").before(html);

	// Get reference to newly added group and scroll to it
	const $newGroup = $("#group-" + groupIndex);

	initializeGroupAccordion(groupIndex);
	// Run twice: once synchronously, once after the browser has laid out the
	// new accordion (some collapsed → expanded transitions delay :visible state).
	reOrderIndex(true);
	setTimeout(function(){ reOrderIndex(true); }, 0);

	refreshSurveySidebar();
	$('#review').trigger('change');

	// Scroll to newly added group
	scrollToNewElement($newGroup[0]);
}

function initializeGroupAccordion(groupIndex) {
	const $questionsAccordion = $("#group-" + groupIndex);
	$questionsAccordion.uiAccordion({
		icons: { "header": "ui-icon-triangle-1-e", "activeHeader": "ui-icon-triangle-1-s" },
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

	// Determine the correct group index and next sibling question index so the
	// placeholders __GROUP_INDEX__ / __QUESTION_INDEX__ in the new partial get
	// replaced with sensible values (rather than left as literals).
	let groupIndex = null;
	const $group = $(group);
	const groupNameAttr = $group.find('input[name*="[wk_survey_que_groups_attributes]"]').first().attr('name');
	const m = groupNameAttr ? groupNameAttr.match(/\[wk_survey_que_groups_attributes\]\[(\d+|\w+)\]/) : null;
	if (m) groupIndex = m[1];
	if (groupIndex == null) groupIndex = newId;

	// Next sibling question index = count of existing top-level questions in this group + 1.
	// Use descendant selector because the group template wraps its first
	// question in .group-questions > .questions_container > .surveyquestion,
	// while dynamic adds land as direct children of .group-questions.
	// Exclude any question inside a follow-up wrapper.
	const existingTopLevelCount = $group.find('.surveyquestion:not(.child-question)').filter(function () {
		return $(this).closest('.followup-inline-row').length === 0;
	}).length;
	const questionIndex = existingTopLevelCount + 1;

	html = html.replace(/__GROUP_INDEX__/g, groupIndex)
	           .replace(/__QUESTION_INDEX__/g, questionIndex);

	const addLink = group.querySelector('.add-question-link');
	let newElem;
	if (addLink) {
		addLink.insertAdjacentHTML('beforebegin', html);
		newElem = $(addLink).prev('.surveyquestion');
	} else {
		group.insertAdjacentHTML('beforeend', html);
		newElem = $(group).find('.surveyquestion').last();
	}

	reOrderIndex(true);
	setTimeout(function(){ reOrderIndex(true); }, 0);
	refreshSurveySidebar();
	$('#review').trigger("change");

	// Scroll to newly added question
	scrollToNewElement(newElem[0]);
	return newElem;
}

// Update group header when name changes

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

$(document).on('input', '.group-name-input, .question-name-input', function() {
	refreshSurveySidebar();
});

$(document).on('click', '.sidebar-question', function() {
	const targetId = $(this).attr('data-sidebar-target');
	if (!targetId) return;

	const targetQuestion = $('[data-sidebar-question-id="' + targetId + '"]');
	if (targetQuestion.length === 0) return;

	const accordionItem = targetQuestion.closest('.group-accordion-item');

	function scrollAndHighlight() {
		$('html, body').animate({ scrollTop: targetQuestion.offset().top - 120 }, 400);
		$('.sidebar-highlight').removeClass('sidebar-highlight');
		targetQuestion.addClass('sidebar-highlight');
		setTimeout(function() { targetQuestion.removeClass('sidebar-highlight'); }, 2000);
	}

	if (accordionItem.length > 0) {
		const accordionContent = accordionItem.children('.group-accordion-content');
		if (accordionContent.length === 0) { scrollAndHighlight(); return; }

		if (accordionContent.is(':hidden')) {
			accordionContent.stop(true, true).slideDown(150);
			const icon = accordionItem.find('.ui-accordion-header-icon');
			if (icon.length > 0) {
				icon.removeClass('ui-icon-triangle-e').addClass('ui-icon-triangle-s');
			}
		}
		setTimeout(function() { scrollAndHighlight(); }, 180);
	} else {
		scrollAndHighlight();
	}
});
// Survey name 3-dot menu
$(function() {
    var $menu = $('#surveyNameContextMenu');
    var $kebab = $('.survey-name-kebab');

    function updateMenuTicks() {
        $menu.find('.kebab-menu-item').each(function() {
            var field = $(this).data('field');
            var $checkbox = $('#' + field);
            var checked = $checkbox.length && $checkbox.prop('checked');
            $(this).toggleClass('is-checked', checked);
        });
    }

    $kebab.on('click', function(e) {
        e.stopPropagation();
        e.preventDefault();

        if ($menu.is(':visible')) {
            $menu.hide();
            return;
        }

        updateMenuTicks();

        // Use getBoundingClientRect for viewport-relative coords so position:fixed lands exactly under the icon
        var rect = this.getBoundingClientRect();
        $menu.css({
            position: 'fixed',
            left: rect.left,
            top: rect.bottom + 4,
            display: 'block'
        });

        $(document).one('click.kebabMenu', function() {
            $menu.hide();
        });
    });

    // Keep menu open on item click so user can toggle multiple options
    $menu.on('click', '.kebab-menu-item', function(e) {
        e.stopPropagation();
        var field = $(this).data('field');
        var $checkbox = $('#' + field);
        if ($checkbox.length) {
            $checkbox.prop('checked', !$checkbox.prop('checked'));
            $checkbox.trigger('change');
        }
        updateMenuTicks();
    });

    $menu.on('click', function(e) {
        e.stopPropagation();
    });
});

// ── Contenteditable group name ────────────────────────────────────────────────

function activateGroupNameEdit(editBtn) {
    var $header = $(editBtn).closest('.group-accordion-header');
    var $span   = $header.find('.group-name-editable');

    if ($span.attr('contenteditable') === 'true') return; // already editing

    $span.attr('contenteditable', 'true').addClass('editing');

    // ── Bind DIRECTLY on the span (not via document delegation) ──────────────
    // Document-level delegation fires AFTER the <h3> handler, so jQuery UI
    // accordion intercepts Space/Tab/arrows first — direct binding fires first.
    $span.on('keydown.groupedit', function (e) {
        // Stop ALL keys from reaching jQuery UI's <h3> handler
        e.stopPropagation();
        e.stopImmediatePropagation();

        if (e.key === 'Enter') {
            e.preventDefault();
            this.blur();
        }
        if (e.key === 'Escape') {
            this.blur();
        }
    });

    // Move caret to end
    $span[0].focus();
    var range = document.createRange();
    var sel   = window.getSelection();
    range.selectNodeContents($span[0]);
    range.collapse(false);
    sel.removeAllRanges();
    sel.addRange(range);
}

$(document).on('blur', '.group-name-editable', function () {
    var $span = $(this);
    var text  = $span.text().trim();
    if (!text) {
        $span.text('');
    }
    // Tear down the direct keydown handler; deactivate edit mode
    $span.off('keydown.groupedit');
    $span.attr('contenteditable', 'false').removeClass('editing');
    $span.closest('.group-accordion-header').find('.group-name-hidden').val(text);
    refreshSurveySidebar();
});

// Fallback document-level handler (handles Enter/Escape if direct binding missed)
$(document).on('keydown', '.group-name-editable', function (e) {
    if (e.key === 'Enter') { e.preventDefault(); this.blur(); }
    if (e.key === 'Escape') { this.blur(); }
});

// =====================================================================
// SURVEY EDITOR REDESIGN — wiring for new UI shell
// =====================================================================
$(function () {
    // ── Settings block collapse ─────────────────────────────────────
    window.edToggleCollapse = function (block) {
        $(block).toggleClass('ed-collapsed');
    };

    // ── App-bar status pill: keep colour + label in sync with the
    //    hidden <select id="survey_status"> ────────────────────────────
    function edSyncStatusPill() {
        var $sel   = $('#survey_status');
        if ($sel.length === 0) return;
        var val    = $sel.val();
        var label  = $sel.find('option:selected').text();
        var $pill  = $('#ed-status-pill');
        $pill.removeClass('ed-st-O ed-st-N ed-st-C').addClass('ed-st-' + val);
        $('#ed-status-label').text(label);
    }
    edSyncStatusPill();
    $('#survey_status').on('change', edSyncStatusPill);

    // ── Breadcrumb name follows the survey-name input ──────────────────
    $('#wksurvey_name').on('input', function () {
        var v = $(this).val().trim();
        $('#ed-survey-crumb-name').text(v || 'New Survey');
    });

    // ── Toggle switches: show/hide sub-row (recur-every) ───────────────
    $('.ed-toggle-cb[data-target]').on('change', function () {
        var target = $(this).data('target');
        if (!target) return;
        $('#' + target).toggle(this.checked);
    });

    // ── "Add intro/closing text" affix toggle (if present) ─────────────
    window.edToggleAffix = function (el) {
        var $body = $(el).closest('.ed-q-body');
        var $existing = $body.find('.ed-q-affix');
        if ($existing.length) {
            $existing.remove();
            $(el).text('＋ Intro / closing text');
            return;
        }
        var html =
            '<div class="ed-q-affix">' +
              '<label>Intro</label><input class="ed-input" placeholder="Shown above…">' +
              '<label>Closing</label><input class="ed-input" placeholder="Shown below…">' +
            '</div>';
        $(el).closest('.ed-q-tools').after(html);
        $(el).text('－ Hide intro / closing text');
    };

    // ── Update question-type-select colour on change ───────────────────
    function edColorTypeSelect() {
        $('select[name*="[question_type]"]').each(function () {
            var $s = $(this);
            $s.removeClass('ed-t-RB ed-t-CB ed-t-TB ed-t-MTB');
            $s.addClass('ed-t-' + $s.val());
        });
    }
    edColorTypeSelect();
    $(document).on('change', 'select[name*="[question_type]"]', edColorTypeSelect);

    // ── Section question count update ──────────────────────────────────
    function edUpdateSectionCounts() {
        $('.group-accordion-item').each(function () {
            // Count all questions (top-level + follow-ups) whose _destroy flag is not set
            // and that are not marked display:none. Don't use :visible because
            // accordion-collapsed sections would report 0 on initial render.
            var n = $(this).find('.surveyquestion').filter(function () {
                if (this.style.display === 'none') return false;
                var destroy = $(this).find('> input[name*="_destroy"]').val();
                return destroy !== '1';
            }).length;
            var label = n + ' question' + (n === 1 ? '' : 's');
            $(this).find('.ed-q-count').text('· ' + label);
        });
    }
    // Run now and once more after the DOM is fully settled (handles cases
    // where the accordion init mutates the tree right after our first call).
    edUpdateSectionCounts();
    $(function () { edUpdateSectionCounts(); });
    setTimeout(edUpdateSectionCounts, 0);

    // ── Inject "More options" toggle into every question ─────────────
    function edInjectMoreToggle() {
        $('.ed-root fieldset.surveyquestion, .ed-root div.surveyquestion.child-question').each(function () {
            if ($(this).find('> .ed-q-more-toggle').length) return;
            var $btn = $(
                '<div class="ed-q-more-toggle" onclick="edToggleQuestionDetails(this)">' +
                '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9l6 6 6-6"/></svg>' +
                'Mandatory · pre-text · post-text</div>'
            );
            $(this).find('> table').after($btn);
        });
    }
    window.edToggleQuestionDetails = function (el) {
        $(el).closest('fieldset.surveyquestion, div.surveyquestion.child-question').toggleClass('ed-q-expanded');
    };
    edInjectMoreToggle();

    // ── Tag sidebar questions with their type for colored dots ─────
    function edTagSidebarTypes() {
        $('.sidebar-question').each(function () {
            var sid = $(this).attr('data-sidebar-target');
            if (!sid) return;
            var $real = $('[data-sidebar-question-id="' + sid + '"]');
            var t = $real.find('select[name*="[question_type]"]').val() || 'RB';
            $(this).removeClass('ed-type-RB ed-type-CB ed-type-TB ed-type-MTB')
                   .addClass('ed-type-' + t);
        });
    }
    edTagSidebarTypes();

    // Re-run after any DOM change driven by add/delete
    var _origReorder = window.reOrderIndex;
    if (typeof _origReorder === 'function') {
        window.reOrderIndex = function () {
            var r = _origReorder.apply(this, arguments);
            edUpdateSectionCounts();
            edInjectMoreToggle();
            edTagSidebarTypes();
            return r;
        };
    }
    var _origRefresh = window.refreshSurveySidebar;
    if (typeof _origRefresh === 'function') {
        window.refreshSurveySidebar = function () {
            var r = _origRefresh.apply(this, arguments);
            edTagSidebarTypes();
            return r;
        };
    }
});



/* =====================================================================
   SURVEY EDITOR - REDESIGN PREVIEW 2 PORT
   Re-implements the question-editor helpers for the new flex/div DOM
   (.qrow > .q-gutter + .q-body > .q-toprow + .choices + .q-tools + .q-affix).
   These overrides replace the previous table-based implementations.
   ===================================================================== */
(function(){

  // ---- helpers ----
  function getGroupQuestionIndex($elInsideQ){
    var $q = $elInsideQ.closest(".surveyquestion").first();
    var nm = $q.find("input[name*=\"[wk_survey_questions_attributes]\"], select[name*=\"[wk_survey_questions_attributes]\"], textarea[name*=\"[wk_survey_questions_attributes]\"]").first().attr("name") || "";
    var m = nm.match(/\[wk_survey_que_groups_attributes\]\[(\d+)\]\[wk_survey_questions_attributes\]\[(\d+)\]/);
    return { groupIndex: m ? m[1] : "0", questionIndex: m ? m[2] : "0", $q: $q };
  }

  // ---- toggleAffix : show/hide the .q-affix that holds header/footer inputs ----
  window.toggleAffix = function(el){
    var $el    = $(el);
    var $tools = $el.closest(".q-tools");
    var $affix = $tools.next(".q-affix");
    if ($affix.length === 0) $affix = $tools.closest(".q-body").find("> .q-affix").first();
    if ($affix.length === 0) return;

    // Cache the "clean" label (without prefix) once, so toggling can't compound.
    var base = $el.data("affixLabel");
    if (typeof base !== "string") {
      base = $el.text().replace(/^\s*[\+\-−–—]+\s*/, "").trim();
      $el.data("affixLabel", base);
    }
    var willShow = !$affix.is(":visible");
    if (willShow) { $affix.css("display","grid"); $el.text("− " + base); }
    else          { $affix.hide();                 $el.text("+ " + base); }
  };
  // keep legacy name working for any leftover handlers
  window.toggleIntroClosing = window.toggleAffix;

  // ---- addChoiceRow : insert a new .choice div before .add-choice ----
  window.addChoiceRow = function(link){
    var $link = $(link);
    var $choices = $link.closest(".choices");
    if ($choices.length === 0) $choices = $link.closest(".q-body").find("> .choices").first();
    if ($choices.length === 0) return;
    var ctx = getGroupQuestionIndex($link);
    var safeId = new Date().getTime() + Math.floor(Math.random() * 1000);
    var $qrow = $link.closest(".qrow, .surveyquestion");
    var glyph = $qrow.hasClass("ed-qtype-CB") ? "check" : "radio";

    var html =
      "<div class=\"choice choice-row\">" +
        "<span class=\"glyph " + glyph + "\"></span>" +
        "<input type=\"hidden\" name=\"wksurvey[wk_survey_que_groups_attributes][" + ctx.groupIndex +
          "][wk_survey_questions_attributes][" + ctx.questionIndex +
          "][wk_survey_choices_attributes][" + safeId + "][id]\">" +
        "<input type=\"text\" size=\"40\" maxlength=\"100\" class=\"choice-text\" " +
          "name=\"wksurvey[wk_survey_que_groups_attributes][" + ctx.groupIndex +
          "][wk_survey_questions_attributes][" + ctx.questionIndex +
          "][wk_survey_choices_attributes][" + safeId + "][name]\">" +
        "<span class=\"pts choice-points-cell\">" + (window.pointsText || "Points") + " " +
          "<input type=\"text\" size=\"5\" maxlength=\"10\" " +
          "name=\"wksurvey[wk_survey_que_groups_attributes][" + ctx.groupIndex +
          "][wk_survey_questions_attributes][" + ctx.questionIndex +
          "][wk_survey_choices_attributes][" + safeId + "][points]\"></span>" +
        "<input type=\"hidden\" name=\"wksurvey[wk_survey_que_groups_attributes][" + ctx.groupIndex +
          "][wk_survey_questions_attributes][" + ctx.questionIndex +
          "][wk_survey_choices_attributes][" + safeId + "][_destroy]\" value=\"0\">" +
        "<span class=\"choice-followup-actions\" style=\"display:inline-flex;align-items:center;gap:4px;\">" +
          (window.addFollowupHtml || "") +
        "</span>" +
        "<a href=\"javascript:void(0)\" title=\"Delete\" onclick=\"DeleteChoice(this)\" class=\"iconbtn danger icon icon-del\">" +
          (window.delIconSvg || (window.delImg || "x")) +
        "</a>" +
      "</div>";

    $(html).insertBefore($link);
  };

  // ---- DeleteChoice : remove a .choice div ----
  window.DeleteChoice = function(link){
    var $row = $(link).closest(".choice");
    if ($row.length === 0) return;
    var destroyField = $row.find("input[name*='[_destroy]']")[0];
    if (destroyField){
      destroyField.value = "1";
      if (destroyField.type === "checkbox") destroyField.checked = true;
      $row.hide();
      if (typeof unlinkQuestion === "function") unlinkQuestion($row);
    } else {
      if (typeof unlinkQuestion === "function") unlinkQuestion($row);
      // also remove a trailing .followup-inline-row sibling if present
      var $next = $row.next(".followup-inline-row");
      if ($next.length) $next.remove();
      $row.remove();
    }
    if (typeof reOrderIndex === "function") reOrderIndex(false);
  };

  // ---- questionTypeChanged : toggle qtype class, glyphs, choices/text-points ----
  window.questionTypeChanged = function(dropdown){
    var $select = $(dropdown);
    var value = $select.val();
    var $q = $select.closest(".surveyquestion, .qrow").first();
    var $choices = $q.find("> .q-body > .choices").first();
    var $tbMtbAdder = $q.find("> .q-body > .tb-mtb-followup-adder-row").first();
    var $tbMtbTools = $q.find("> .q-body > .q-tools > .tb-mtb-tools").first();

    // qtype class
    $q.removeClass("ed-qtype-RB ed-qtype-CB ed-qtype-TB ed-qtype-MTB").addClass("ed-qtype-" + value);
    // select colour
    $select.removeClass("rb cb tb mtb").addClass(value.toLowerCase());

    if (value === "RB" || value === "CB"){
      // show choices, hide tb-mtb extras
      $choices.show();
      $q.find("> .q-body > .choices > .add-choice").show();
      $tbMtbAdder.hide();
      $tbMtbTools.hide();
      // swap glyphs
      var newGlyph = value === "CB" ? "check" : "radio";
      $choices.find("> .choice > .glyph").removeClass("radio check").addClass(newGlyph);
      // un-destroy any existing choice rows that were hidden when toggling away
      $choices.find("> .choice").each(function(){
        var d = this.querySelector("input[name*='[_destroy]']");
        if (d){ d.value = "0"; if (d.type === "checkbox") d.checked = false; }
        this.style.display = "";
      });
      // ensure at least one choice exists
      if ($choices.find("> .choice").length === 0){
        var $addLink = $choices.find("> .add-choice").first();
        if ($addLink.length) addChoiceRow($addLink[0]);
      }
    } else {
      // TB / MTB
      $choices.hide();
      $choices.find("> .choice").each(function(){
        var d = this.querySelector("input[name*='[_destroy]']");
        if (d){
          d.value = "1";
          if (d.type === "checkbox") d.checked = true;
        }
      });
      $tbMtbAdder.show();
      $tbMtbTools.css("display","inline-flex");
    }
    if (typeof reOrderIndex === "function") reOrderIndex(false);
  };

  // ---- reOrderIndex : numbering for new DOM ----
  window.reOrderIndex = function(onlyVisible){
    onlyVisible = (onlyVisible === true);
    var groupCounter = 0;
    var globalSortOrder = 0;
    var globalGroupSortOrder = 0;
    var ungroupedCounter = 0;

    function processFollowUps($parentQ, parentIndex){
      var $body = $parentQ.find("> .q-body").first();
      var choiceIdx = 0;

      function _writeChildIndex($child, label){
        // The badge lives in .q-toprow IN FRONT of the title input.
        // Auto-create the span there if missing so old DOM or
        // JS-injected followups always get a visible number.
        var $top = $child.find("> .q-body > .q-toprow").first();
        var $idx = $top.find("> .childIndexNo").first();
        if ($idx.length === 0 && $top.length){
          $top.prepend('<span class="childIndexNo q-num q-num-inline"></span>');
          $idx = $top.find("> .childIndexNo").first();
        }
        if ($idx.length){
          $idx.html("<b>" + label + "</b>");
        }
      }

      // RB/CB: per choice — `.choices > .choice` and `.choices > .followup-inline-row`
      $body.find("> .choices > .choice, > .choices > .followup-inline-row").each(function(){
        if ($(this).hasClass("choice")){
          if ($(this).css("display") !== "none") choiceIdx++;
        } else if ($(this).hasClass("followup-inline-row")){
          var $child = $(this).find("> .surveyquestion.child-question, > .qrow").first();
          if ($child.length && $child.css("display") !== "none"){
            var cur = choiceIdx > 0 ? choiceIdx : 1;
            globalSortOrder++;
            var label = parentIndex + "." + cur;
            _writeChildIndex($child, label);
            $child.find("> input.question-sort-order").val(globalSortOrder);
            processFollowUps($child, label);
          }
        }
      });
      // TB/MTB: single follow-up inside tb-mtb-followup-adder-row
      $body.find("> .tb-mtb-followup-adder-row > .followup-inline-row").each(function(idx){
        var $child = $(this).find("> .surveyquestion.child-question, > .qrow").first();
        if ($child.length && $child.css("display") !== "none"){
          var cur = idx + 1;
          globalSortOrder++;
          var label = parentIndex + "." + cur;
          _writeChildIndex($child, label);
          $child.find("> input.question-sort-order").val(globalSortOrder);
          processFollowUps($child, label);
        }
      });
    }

    // Helper: returns true if the element OR its enclosing
    // .group-container-wrap is soft-removed (display:none inline OR
    // _destroy=1). We DO NOT use jQuery :visible because that also returns
    // false when an ancestor (a collapsed accordion panel) is hidden, which
    // would leave brand-new questions in a fresh accordion un-numbered.
    // DeleteGroup hides the .group-container-wrap, not the
    // .group-accordion-item — so we MUST climb to that wrapper too.
    function _isRemoved($el){
      if ($el[0].style && $el[0].style.display === "none") return true;
      var $wrap = $el.closest(".group-container-wrap");
      if ($wrap.length && $wrap[0].style.display === "none") return true;
      // For groups, the _destroy input lives anywhere inside the group block.
      // For questions, it's a direct child of the question root.
      var $d = $el.is(".group-accordion-item, .group-ungrouped-questions")
        ? $el.find("input[name*='[wk_survey_que_groups_attributes]'][name$='[_destroy]']").first()
        : $el.children("input[name*='[_destroy]']").first();
      if ($d.length && ($d.val() === "1" || $d.prop("checked"))) return true;
      return false;
    }

    $(".group-accordion-item, .group-ungrouped-questions").each(function(){
      var $group = $(this);
      if (_isRemoved($group)) return;
      globalGroupSortOrder++;
      $group.children(".group-sort-order").val(globalGroupSortOrder);

      // NOTE: the group template wraps its first question in
      //   .group-questions > .questions_container > .surveyquestion
      // while dynamically-added questions land as direct children of
      //   .group-questions
      // So we need a DESCENDANT selector here, not a direct-child one.
      // `:not(.child-question)` already excludes inline follow-up questions,
      // and the .followup-inline-row guard below excludes deeper nesting.
      function _isTopLevel($q){
        // Excludes any question that lives inside a follow-up wrapper.
        return $q.closest(".followup-inline-row").length === 0;
      }

      if ($group.hasClass("group-accordion-item")){
        groupCounter++;
        $group.find(".group-accordion-header .group-num").text("GROUP " + groupCounter);

        // Sync hidden name field if blank (server-rendered group whose name
        // was never saved — e.g. the initial default group on a new survey).
        // Without this the form submits name="" and the view treats the group
        // as "ungrouped", losing all its questions in the accordion layout.
        var $nameHidden   = $group.find(".group-accordion-header .group-name-hidden").first();
        var $nameEditable = $group.find(".group-accordion-header .group-name-editable").first();
        if (!$nameHidden.val()) {
          var nm = $nameEditable.text().trim() || ("Group-" + groupCounter);
          $nameHidden.val(nm);
          $nameEditable.text(nm);
        }
        var qCount = 0;
        $group.find(".group-questions .surveyquestion:not(.child-question)").each(function(){
          var $q = $(this);
          if (!_isTopLevel($q)) return;
          if (_isRemoved($q)) return;
          qCount++;
          globalSortOrder++;
          var idx = groupCounter + "." + qCount + ".";
          $q.find("> .q-gutter > .q-num").html("<b>" + idx + "</b>");
          $q.children("input.question-sort-order").val(globalSortOrder);
          processFollowUps($q, groupCounter + "." + qCount);
        });
      } else {
        $group.find(".surveyquestion:not(.child-question)").each(function(){
          var $q = $(this);
          if (!_isTopLevel($q)) return;
          if (_isRemoved($q)) return;
          ungroupedCounter++;
          globalSortOrder++;
          var idx = "" + ungroupedCounter + ".";
          $q.find("> .q-gutter > .q-num").html("<b>" + idx + "</b>");
          $q.children("input.question-sort-order").val(globalSortOrder);
          processFollowUps($q, "" + ungroupedCounter);
        });
      }
    });

    $(".followup-linked-label").each(function(){
      var html = $(this).html();
      if (html && html.indexOf("Linked") < 0) {
        $(this).html(window.linkedLabelHtml
          ? $(window.linkedLabelHtml).html()
          : '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M7 17L17 7M9 7h8v8"/></svg> Linked'
        );
      }
    });
  };

  // ---- removeFollowUpLink : new selectors ----
  window.removeFollowUpLink = function(link){
    if (!confirm("Are you sure you want to unlink this follow-up question?")) return;
    var $el = $(link);
    // context container: a .choice (RB/CB) or .tb-mtb-followup-cell (TB/MTB)
    var $ctx = $el.closest(".choice");
    if ($ctx.length === 0) $ctx = $el.closest(".tb-mtb-followup-cell");
    if ($ctx.length === 0) $ctx = $el.closest(".q-tools");
    if ($ctx.length === 0) return;

    $ctx.find(".followup-val").val("");
    $ctx.find("input[name*='[follow_up_temp_id]'], input[name*='[follow_up_question_id]']").val("");
    $ctx.find(".followup-linked-label").hide();
    $ctx.find(".icon-unlink, .fu-unlink").hide();
    $ctx.find("a[onclick*='addFollowUpQuestion']").show();

    // Hide the inline follow-up div that immediately follows this choice
    if ($ctx.hasClass("choice")){
      $ctx.next(".followup-inline-row").hide();
    } else {
      // TB/MTB: follow-up div lives as a sibling inside .tb-mtb-followup-adder-row
      var $adder = $el.closest(".tb-mtb-followup-adder-row");
      if ($adder.length) $adder.find("> .followup-inline-row").hide();
    }

    if (typeof reOrderIndex === "function") reOrderIndex(false);
    if (typeof refreshSurveySidebar === "function") refreshSurveySidebar();
  };

  // ---- _clearFollowUpUI : updated ----
  window._clearFollowUpUI = function($ctx){
    $ctx.find(".followup-val").val("");
    $ctx.find("input[name*='[follow_up_temp_id]'], input[name*='[follow_up_question_id]']").val("");
    $ctx.find(".followup-linked-label, .icon-unlink, .fu-unlink").remove();
    $ctx.find("a[onclick*='addFollowUpQuestion']").show();
    if ($ctx.hasClass("choice")){
      $ctx.next(".followup-inline-row").hide();
    }
  };

  // ---- unlinkAllLinkersTo : new selectors ----
  window.unlinkAllLinkersTo = function(id, tempId, exceptCtx){
    if (id){
      $(".followup-val[value='" + id + "']").each(function(){
        var $ctx = $(this).closest(".choice, .tb-mtb-followup-cell, .q-tools");
        if (!exceptCtx || !$ctx.is(exceptCtx)) _clearFollowUpUI($ctx);
      });
    }
    if (tempId){
      $("input[name*='[follow_up_temp_id]'][value='" + tempId + "']").each(function(){
        var $ctx = $(this).closest(".choice, .tb-mtb-followup-cell, .q-tools");
        if (!exceptCtx || !$ctx.is(exceptCtx)) _clearFollowUpUI($ctx);
      });
    }
  };

  // ---- _doCreateFollowUp : create + attach inline ----
  window._doCreateFollowUp = function(link){
    var $link = $(link);
    var $choice = $link.closest(".choice");
    var $tbCell = $link.closest(".tb-mtb-followup-cell");
    var $ctx = $choice.length ? $choice : $tbCell;
    if ($ctx.length === 0) return;

    var nameAttr = $ctx.find("input[name*='[wk_survey_choices_attributes]']").first().attr("name");
    if (!nameAttr) return;

    // Find a place to spawn the new question
    var $groupContainer = $link.closest(".group-questions");
    if ($groupContainer.length === 0) $groupContainer = $link.closest(".ungrouped-section");
    var newQuestion;
    if ($groupContainer.length > 0){
      var $addBtn = $groupContainer.find(".add-question-link a.icon-add").first();
      if ($addBtn.length > 0) newQuestion = addQuestions($addBtn[0]);
      else newQuestion = addUngroupedQues();
    } else {
      newQuestion = addUngroupedQues();
    }
    if (!newQuestion || newQuestion.length === 0) return;

    newQuestion.addClass("child-question qrow-inline");
    newQuestion.find("a[title='Move Up'], a[title='Move Down']").hide();

    // Inline follow-ups don't render .q-gutter — strip it and prepend the .fu-tag
    // header to .q-body so the layout matches the static ERB inline branch.
    newQuestion.find("> .q-gutter").remove();
    var $fuBody = newQuestion.find(".q-body").first();
    if ($fuBody.find(".fu-tag").length === 0) {
      var base = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 18l6-6-6-6"/></svg>' +
                 '<span class="fu-tag-base">FOLLOW-UP</span>';
      $fuBody.prepend('<div class="fu-tag">' + base + '</div>');
    }
    // Always inject choice label into fu-tag (after tag is guaranteed to exist)
    var fuChoiceName = $choice.length ? ($choice.find(".choice-text").val() || "") : "";
    var $fuTag = $fuBody.find(".fu-tag").first();
    if ($fuTag.length && fuChoiceName && $fuTag.find(".fu-tag-choice").length === 0) {
      $fuTag.append('<span class="fu-tag-choice">· ' + fuChoiceName + '</span>');
    }
	// Inject the question-number badge IN FRONT of the title input
    // (matches the static ERB inline branch layout).
    var $fuTopRow = $fuBody.find("> .q-toprow").first();
    if ($fuTopRow.length && $fuTopRow.find("> .childIndexNo").length === 0){
      $fuTopRow.prepend('<span class="childIndexNo q-num q-num-inline"></span>');
    }

    var tempId = "tmp_" + new Date().getTime() + Math.floor(Math.random() * 1000);
    var qInputNew = newQuestion.find("input[name*='[wk_survey_questions_attributes]']").first();
    var qName = qInputNew.attr("name");
    var tempInputPath = qName.replace(/\[(name|id|sort_order|question_type)\]$/, "[temp_id]");
    if (tempInputPath === qName) tempInputPath = qName.substring(0, qName.lastIndexOf("[")) + "[temp_id]";
    newQuestion.append('<input type="hidden" name="' + tempInputPath + '" value="' + tempId + '">');

    var choiceName = $choice.length ? ($choice.find(".choice-text").val() || "followup") : "followup";

    var choiceTempPath = nameAttr.replace(/\[(name|id|points|is_answer)\]$/, "[follow_up_temp_id]");
    if (choiceTempPath === nameAttr) choiceTempPath = nameAttr.substring(0, nameAttr.lastIndexOf("[")) + "[follow_up_temp_id]";

    var $target = $link.parent();
    $target.find("input[name*='[follow_up_temp_id]']").remove();
    $target.append('<input type="hidden" class="followup-val" name="' + choiceTempPath + '" value="' + tempId + '">');

    // Wrap and place follow-up
    var $wrap = $('<div class="followup follow-up-container followup-inline followup-inline-row" data-choice-name="' + choiceName + '"></div>');
    $wrap.append(newQuestion);
    if ($choice.length){
      $choice.after($wrap);
    } else {
      // TB/MTB: append inside .tb-mtb-followup-adder-row
      var $adder = $link.closest(".tb-mtb-followup-adder-row");
      if ($adder.length) $adder.append($wrap);
      else $link.closest(".q-body").append($wrap);
    }

    $target.find(".followup-linked-label, .icon-unlink, .fu-unlink").remove();
    $target.append(window.linkedLabelHtml + " " + window.unlinkFollowupHtml);
    $(link).hide();

    if (typeof reOrderIndex === "function") reOrderIndex(false);
    if (typeof refreshSurveySidebar === "function") refreshSurveySidebar();

    if (newQuestion.offset()){
      $("html, body").animate({ scrollTop: newQuestion.offset().top - 100 }, 500);
    }
  };

  // ---- _doLinkExistingFollowUp : updated context ----
  window._doLinkExistingFollowUp = function(link, targetId, isTemp, indexNo){
    var $link = $(link);
    var $ctx = $link.closest(".choice");
    if ($ctx.length === 0) $ctx = $link.closest(".tb-mtb-followup-cell");
    if ($ctx.length === 0) return;

    var nameAttr = $ctx.find("input[name*='[wk_survey_choices_attributes]']").first().attr("name");
    if (!nameAttr) return;

    var $target = $link.parent();
    $target.find("input[name*='[follow_up_question_id]'], input[name*='[follow_up_temp_id]']").remove();

    if (isTemp){
      var p = nameAttr.replace(/\[(name|id|points|is_answer)\]$/, "[follow_up_temp_id]");
      if (p === nameAttr) p = nameAttr.substring(0, nameAttr.lastIndexOf("[")) + "[follow_up_temp_id]";
      $target.append('<input type="hidden" class="followup-val" name="' + p + '" value="' + targetId + '">');
    } else {
      var p2 = nameAttr.replace(/\[(name|id|points|is_answer)\]$/, "[follow_up_question_id]");
      if (p2 === nameAttr) p2 = nameAttr.substring(0, nameAttr.lastIndexOf("[")) + "[follow_up_question_id]";
      $target.append('<input type="hidden" class="followup-val" name="' + p2 + '" value="' + targetId + '">');
    }
    $target.find(".followup-linked-label, .icon-unlink, .fu-unlink").remove();
    $target.append(window.linkedLabelHtml + " " + window.unlinkFollowupHtml);
    $link.hide();
    if (typeof reOrderIndex === "function") reOrderIndex(false);
    if (typeof refreshSurveySidebar === "function") refreshSurveySidebar();
  };

  // ---- unlinkQuestion : new context selector ----
  window.unlinkQuestion = function($ctx){
    var followUpId = $ctx.find(".followup-val").val();
    var followUpTempId = $ctx.find("input[name*='[follow_up_temp_id]']").last().val();
    var questionToDelete = null;

    if (followUpId){
      var qInputs = $("input[name$='[id]'][value='" + followUpId + "']").filter(function(){
        return this.name.indexOf("[wk_survey_questions_attributes]") >= 0;
      });
      if (qInputs.length > 0) questionToDelete = qInputs.closest(".surveyquestion");
    } else if (followUpTempId){
      var qInputs2 = $("input[name$='[temp_id]'][value='" + followUpTempId + "']");
      if (qInputs2.length > 0) questionToDelete = qInputs2.closest(".surveyquestion");
    }

    if (questionToDelete && questionToDelete.length > 0){
      unlinkAllLinkersTo(followUpId, followUpTempId, $ctx);
      var destroyField = questionToDelete.find("input[name*='_destroy']");
      if (destroyField.length){
        if (destroyField.is(":checkbox")) destroyField.prop("checked", true);
        else destroyField.val("1");
      } else {
        questionToDelete.remove();
      }
      var $container = questionToDelete.closest(".follow-up-container, .followup-inline-row");
      if ($container.length) $container.hide();
      else questionToDelete.hide();
      if (typeof reOrderIndex === "function") reOrderIndex(true);
    }
    _clearFollowUpUI($ctx);
  };

  // ---- updateChoiceLabels : no-op for new DOM (we no longer show "Choice N" labels) ----
  window.updateChoiceLabels = function(){ /* labels are now glyphs, not text */ };

  // ---- Initialize affix state and qtype select colour on page load ----
  $(function(){
    $(".q-affix").each(function(){
      var hasContent = false;
      $(this).find("input[type=text]").each(function(){ if ($(this).val()) hasContent = true; });
      if (hasContent) $(this).css("display","grid"); else $(this).hide();
    });
    $(".q-type-select").each(function(){
      var v = $(this).val();
      $(this).removeClass("rb cb tb mtb").addClass((v || "RB").toLowerCase());
    });

    // jQuery UI sortable for top-level questions inside each .group-questions
    if ($.fn.sortable){
      $(".group-questions").each(function(){
          $(this).sortable({
            items: "> .surveyquestion:not(.child-question)",
            handle: ".q-grip",
            axis: "y",
            tolerance: "pointer",
            placeholder: "ui-sortable-placeholder",
            stop: function(){
              if (typeof reOrderIndex === "function") reOrderIndex(false);
              if (typeof refreshSurveySidebar === "function") refreshSurveySidebar();
            }
          });
      });
    }
  });

})();
