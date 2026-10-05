 $(document).ready(function() {
	hideLogDetails(null);
	var entry = 'time_entry'
	var log_type = document.getElementById("log_type").value;
	if(log_type == 'E') entry = 'wk_expense_entry';
	if(['M', 'A', 'RA'].includes(log_type)) entry = 'wk_material_entry';
	if((document.getElementById(entry+'_project_id')) != null)
	{
		$('#'+entry+'_project_id').change(function(){
			var project=$(this);
			uid = document.getElementById('userId').value;
				loadSpentFors(project.val(), 'spent_for', false, uid)

			const allowedProjs = $('#allowedProjects').val();
			if(allowedProjs) allowedProjs.includes(this.value) ? $('#issuelogtable').show() : $('#issuelogtable').hide();
		});
	}

	//Time Tracking
	const spent_id = (new URL(window.location.href)).pathname.split('/')[2];
	if(parseInt(spent_id) > 0) $('#clock_action').val() == '' ? $('#issuelogtable').hide() : $('#issuelogtable').show();

	$('#'+entry+'_user_id, #'+entry+'_hours, #log_type, #'+entry+'_spent_on').change(function(){
		const logType = $('#log_type').val();
		var entry = 'time_entry'
		if(logType == 'E') entry = 'wk_expense_entry';
		if(['M', 'A', 'RA'].includes(logType)) entry = 'wk_material_entry';
		const clockAction = $('#clock_action').val();
		if((parseInt(spent_id) > 0 && clockAction == '') || (!(parseInt(spent_id) > 0) && clockAction == '') &&
			(($('#'+entry+'_user_id').length > 0 && $('#'+entry+'_user_id').val() != $('#current_user').val()) || ( logType == 'T' && $('#'+entry+'_hours').val() != '')) || (!(parseInt(spent_id) > 0) && $('#'+entry+'_spent_on').val() != new Date().toJSON().slice(0,10).replace(/-/g,'-')))
		{
			$('#issuelogtable').hide();
		}
		else if(['T', 'A'].includes(logType))
			$('#issuelogtable').show();
	});

	if($('#clock_action').val() == 'S'){
		$('#'+entry+'_spent_on').prop('disabled', true);
		$('#'+entry+'_hours').val(0.1).prop('disabled', true);
		$('#issueLogger').appendTo('#e_issueLogger');
		if($('#log_type').val() == 'T')
			$('#'+entry+'_hours').css({ float: 'left', 'margin-right': '10px' }).parent('p').append($('#logTimer'));
		else
			$('#logTimer').css({ 'padding-left': '10px', 'padding-right': '10px' }).insertAfter($('#product_quantity').closest('.material-quantity-uom'));
	}

	$('#issueLogger').on('click', function(){
		var clock_action = $('#clock_action').val();
		var newDate = new Date();
		clock_action = clock_action == '' || clock_action == 'E' ? 'S' : 'E';
		$('#clock_action').val(clock_action);
		if(clock_action == 'S'){
			const spentOn = (newDate.toISOString()).split('T')[0];
			$('#'+entry+'_spent_on').val(spentOn).prop('disabled', true);
			$('#h_'+entry+'_spent_on').val(spentOn);
			$('#h_'+entry+'_spent_on').prop('name', ''+entry+'[spent_on]');
			$('#'+entry+'_hours').val(0.1).prop('disabled', true);
			$('#h_'+entry+'_hours').prop('name', ''+entry+'[hours]');
			$('.issueLog img').prop('src','/plugin_assets/redmine_wktime/images/finish.png');
			$('#issueLogger').appendTo('#e_issueLogger').css({ background: 'red' }).html('stop');
			$('#end_on').val('');
			$('#start_on').val(newDate.toISOString());
			// $('#td_start_on').html(newDate.toISOString().split('T'));
			$('#offSet').val(newDate.getTimezoneOffset());
			$('#new_'+entry+'').submit();
		}
		else{
			$('#'+entry+'_spent_on').prop('disabled', false);
			$('#h_'+entry+'_spent_on').prop('name', 'h_'+entry+'[spent_on]');
			$('#'+entry+'_hours').prop('disabled', false);
			$('#h_'+entry+'_hours').prop('name', 'h_'+entry+'[hours]');
			$('#e_issueLogger').html('');
			$('#offSet').val(newDate.getTimezoneOffset());
			$('.edit_'+entry+'').submit();
		}
		$('#clock_action').val(clock_action);
	});

	$('.edit_'+entry+' .new_'+entry+'').submit(function(){
		sessionStorage.setItem("spent_type", $('#log_type').val());
	});
});

function updateTotal(currId, nxtId, setId, currencyId)
{
	var currElement = document.getElementById(currId);
	var nxtElement = document.getElementById(nxtId);
	var totAmount = parseFloat(currElement.value) * parseFloat(nxtElement.value);
	document.getElementById(setId).innerHTML = document.getElementById(currencyId).innerHTML + totAmount.toFixed(2);
}
	$(function () {
		var $single = $('#materialtable');
		var $grid = $('#material-grid-wrapper');
		var $rows = $('#material-grid tbody');
		var $toggle = $('#bulk-entry-toggle');
		var $singleToggle = $('#grid-single-entry-toggle');
		var nextRow = 0;

		// Material, Asset, and Rental Asset use WkMaterialEntry and can share the bulk-item UI.
		function isInventoryLog() { return ['M', 'A', 'RA'].includes($('#log_type').val()); }
		function isAssetLog() { return ['A', 'RA'].includes($('#log_type').val()); }
		function parseMaterialQuantity(value) {
			var normalizedValue = String(value == null ? '' : value).trim();
			if (!/^(?:\d+(?:\.\d*)?|\.\d+)$/.test(normalizedValue)) return null;
			var quantity = Number(normalizedValue);
			return isFinite(quantity) ? quantity : null;
		}
		function quantityNumberError($quantity) {
			return $quantity.data('numericError') || 'Quantity must be a number.';
		}
		function validateNumericQuantity($quantity) {
			if (String($quantity.val()).trim() === '' || parseMaterialQuantity($quantity.val()) !== null) return true;
			alert(quantityNumberError($quantity));
			$quantity.focus();
			return false;
		}
		function updateSingleEntryFields() {
			$('#materialtable .material-single-done-field').toggle(isAssetLog());
			$('#materialtable .material-single-cost-field').toggle($('#log_type').val() === 'M');
			if (!isAssetLog()) $('#unittext').empty();
		}
		function inventoryType() { return $('#log_type').val() === 'M' ? 'I' : $('#log_type').val(); }
		function replaceOptions($select, response, blank) {
			var options = [];
			if (blank) options.push(new Option('', '', false, false));
			$.each(response.split('\n'), function (_, line) {
				var separator = line.indexOf(',');
				if (separator === -1) return;
				options.push(new Option(line.substring(separator + 1), line.substring(0, separator).replace(/_/g, ','), false, false));
			});
			$select.empty().append(options);
		}
		function loadOptions($select, data, blank, complete) {
			var previousRequest = $select.data('optionsRequest');
			if (previousRequest && previousRequest.readyState !== 4) previousRequest.abort();
			var request = $.ajax({
				url: productModifyUrl,
				type: 'get',
				dataType: 'text',
				data: data,
				success: function (response) {
					// Ignore responses for rows removed or changed during the request.
					if (!$select.length || !document.documentElement.contains($select[0])) return;
					replaceOptions($select, response, blank);
					if (complete) complete();
				},
				complete: function () {
					if ($select.data('optionsRequest') === request) $select.removeData('optionsRequest');
				}
			});
			$select.data('optionsRequest', request);
		}
		function loadProducts($row, selectFirst) {
			var $products = $row.find('.material-grid-product');
			loadOptions($products, { ptype: 'product', log_type: $('#log_type').val() }, false, function () {
				if ($products.find('option').length) $products.prop('selectedIndex', 0);
				loadItems($row);
			});
		}
		function clearRowItemDetails($row) {
			$row.removeData('inventoryItemId availableQuantity costPrice currency productSerialNumbers unitText');
			$row.find('input[name$="[inventory_item_id]"], input[name$="[uom_id]"], input[name$="[quantity]"], input[name$="[selling_price]"]').val('');
			$row.find('input[name$="[quantity]"]').removeAttr('data-available-quantity');
			$row.find('textarea[name$="[serial_numbers]"]').val('');
			$row.find('.material-grid-serial-warning').hide();
			$row.find('.available-quantity, .material-grid-uom-label, .material-grid-currency, .material-row-total').empty();
		}
		function markRowEntered($row) {
			$row.find('.material-grid-entered').val('1');
		}
		function validateRowSerialNumbers($row) {
			var serialNumbers = $row.find('textarea[name$="[serial_numbers]"]').val();
			var allowedSerialNumbers = $row.data('productSerialNumbers') || '[]';
			try {
				if (typeof allowedSerialNumbers === 'string') allowedSerialNumbers = JSON.parse(allowedSerialNumbers);
			} catch (error) {
				allowedSerialNumbers = [];
			}
			var hasInvalidSerialNumber = serialNumbers.trim() !== '' && allowedSerialNumbers.length > 0 &&
				serialNumbers.split(',').some(function (number) {
					return !allowedSerialNumbers.includes(number.trim());
				});
			$row.find('.material-grid-serial-warning').toggle(hasInvalidSerialNumber);
			return !hasInvalidSerialNumber;
		}
		function loadItems($row) {
			var productId = $row.find('.material-grid-product').val();
			var $items = $row.find('.material-grid-product-item');
			clearRowItemDetails($row);
			if (!productId) { $items.empty(); return; }
			loadOptions($items, { ptype: 'product_item', id: productId, log_type: inventoryType(), location_id: $('#material_grid_location_id').val() }, false, function () {
				if ($items.find('option').length) $items.prop('selectedIndex', 0);
				if ($items.val()) loadItemDetails($row);
				else clearRowItemDetails($row);
			});
		}
		function loadItemDetails($row) {
			var itemId = $row.find('.material-grid-product-item').val();
			if (!itemId) return;
			var requestedLogType = inventoryType();
			var previousRequest = $row.data('itemDetailsRequest');
			if (previousRequest && previousRequest.readyState !== 4) previousRequest.abort();
			var request = $.ajax({ url: productModifyUrl, type: 'get', dataType: 'text', data: { ptype: 'inventory_item', id: itemId, log_type: requestedLogType }, success: function (response) {
				if (!document.documentElement.contains($row[0]) ||
					$row.data('itemDetailsRequest') !== request ||
					$row.find('.material-grid-product-item').val() !== itemId ||
					inventoryType() !== requestedLogType) return;
				var values = response.split(',');
				var availableQuantity = values[1] || '';
				$row.data('inventoryItemId', values[0] || itemId);
				$row.data('availableQuantity', parseFloat(String(availableQuantity).replace(/,/g, '')) || 0);
				$row.find('input[name$="[inventory_item_id]"]').val(values[0] || itemId);
				$row.data('costPrice', values[2] || '');
				$row.data('currency', values[3] || '');
				var productSerialNumbers = [];
				if (typeof getSerialNumbersRange === 'function' && values[6] && !isNaN(values[6])) {
					productSerialNumbers = getSerialNumbersRange(values[5], values[6], values[7]);
				}
				$row.data('productSerialNumbers', JSON.stringify(productSerialNumbers));
				validateRowSerialNumbers($row);
				$row.data('unitText', values[5] || '');
				$row.find('.available-quantity').text(availableQuantity);
				$row.find('input[name$="[quantity]"]').attr('data-available-quantity', availableQuantity);
				$row.find('input[name$="[selling_price]"]').val(values[4] || '');
				updateRowTotal($row);
			}, complete: function () {
				if ($row.data('itemDetailsRequest') === request) $row.removeData('itemDetailsRequest');
			}});
			$row.data('itemDetailsRequest', request);
			loadUomLabel($row, itemId);
		}
		function loadUomLabel($row, itemId) {
			var previousRequest = $row.data('uomRequest');
			if (previousRequest && previousRequest.readyState !== 4) previousRequest.abort();
			var request = $.ajax({ url: productModifyUrl, type: 'get', dataType: 'text', data: { ptype: 'uom_id', id: itemId }, success: function (response) {
				if (!$row.length || !document.documentElement.contains($row[0]) ||
					$row.data('uomRequest') !== request ||
					$row.find('.material-grid-product-item').val() !== itemId) return;
				var valueAndLabel = (response || '').trim().split(',');
				$row.find('input[name$="[uom_id]"]').val(valueAndLabel[0] || '');
				$row.find('.material-grid-uom-label').text(valueAndLabel.slice(1).join(',') || '');
			}, complete: function () {
				if ($row.data('uomRequest') === request) $row.removeData('uomRequest');
			}});
			$row.data('uomRequest', request);
		}
		function syncSingleSelect($select) {
			var $dropdown = $select.closest('.ui.dropdown');
			if (!$dropdown.length) $dropdown = $select.siblings('.ui.dropdown').first();
			if ($dropdown.length && $.fn.dropdown) {
				$dropdown.dropdown('refresh');
				if ($select.find('option').length && $select.val()) {
					$dropdown.dropdown('set selected', $select.val());
				} else {
					// The sidebar theme keeps a generated menu and label beside the
					// native select. Clear both when an AJAX response has no options.
					$dropdown.children('.menu').empty();
					$dropdown.children('.text').empty().addClass('default');
					$dropdown.removeClass('active visible');
				}
			}
		}
		function clearSingleEntryItemDetails() {
			$('#inventory_item_id, #uom_id, #product_cost_price, #product_sell_price').val('');
			$('#available_quantity, #uom_label, #spcurrency, #cpcurrency, #total, #unittext').text('');
			$('#product_quantity').val('');
			$('#product_serial_numbers').val('[]');
			$('#material_sn').val('');
			$('#warn_serial_number').hide();
		}
		function reloadSingleEntryItems(logType) {
			var $product = $('#product');
			var $items = $('#product_item');
			var productId = $product.val();
			if (!$product.val()) {
				$items.empty();
				syncSingleSelect($items);
				clearSingleEntryItemDetails();
				updateMode();
				return;
			}
			loadOptions($items, { ptype: 'product_item', id: productId, log_type: logType === 'M' ? 'I' : logType, location_id: $('#location_id').val() }, false, function () {
				if ($('#log_type').val() !== logType || $product.val() !== productId) return;
				$items.prop('selectedIndex', 0);
				syncSingleSelect($items);
				if ($items.val()) {
					productItemChanged('product_item', 'product_quantity', 'product_cost_price', 'product_sell_price', $('#userId').val(), 'log_type');
				} else {
					clearSingleEntryItemDetails();
				}
				updateMode();
			});
		}
		function reloadSingleEntryProducts() {
			var logType = $('#log_type').val();
			if (!isInventoryLog()) return;
			var $product = $('#product');
			loadOptions($product, { ptype: 'product', log_type: logType }, false, function () {
				if ($('#log_type').val() !== logType) return;
				$product.prop('selectedIndex', 0);
				syncSingleSelect($product);
				reloadSingleEntryItems(logType);
			});
		}
		function updateSingleUomLabel() {
			var itemId = $('#product_item').val();
			if (!itemId) {
				$('#uom_id').val('');
				$('#uom_label').text('');
				return;
			}
			var $item = $('#product_item');
			var previousRequest = $item.data('singleUomRequest');
			if (previousRequest && previousRequest.readyState !== 4) previousRequest.abort();
			var request = $.ajax({ url: productModifyUrl, type: 'get', dataType: 'text', data: { ptype: 'uom_id', id: itemId }, success: function (response) {
				if ($item.data('singleUomRequest') !== request || $item.val() !== itemId) return;
				var valueAndLabel = (response || '').trim().split(',');
				$('#uom_id').val(valueAndLabel[0] || '');
				$('#uom_label').text(valueAndLabel.slice(1).join(',') || '');
			}, complete: function () {
				if ($item.data('singleUomRequest') === request) $item.removeData('singleUomRequest');
			}});
			$item.data('singleUomRequest', request);
		}
		function addRow(loadDefaults, loadProductOptions) {
			var html = $('#material-grid-row-template').html().replace(/INDEX/g, nextRow++);
			var $row = $(html).appendTo($rows);
			if ($row.is(':first-child')) $row.find('.material-grid-remove').hide();
			$row.find('.material-grid-done-column').toggle(isAssetLog());
			$row.find('.material-grid-product').on('change', function () { markRowEntered($row); loadItems($row); });
			$row.find('.material-grid-product-item').on('change', function () { markRowEntered($row); loadItemDetails($row); });
			if (loadProductOptions !== false) loadProducts($row, loadDefaults !== false);
			return $row;
		}
		function ensureDefaultGridRows() {
			if (!$rows.children().length) addRow();
			while ($rows.children().length < 5) addRow(false);
		}
		function refreshAvailableQuantities() {
			var rowsByInventory = {};
			$rows.children('.material-grid-row').each(function () {
				var $row = $(this);
				var inventoryId = $row.data('inventoryItemId');
				if (!inventoryId) return;
				(rowsByInventory[inventoryId] ||= []).push($row);
			});
			$.each(rowsByInventory, function (_, itemRows) {
				var availableQuantity = parseFloat(itemRows[0].data('availableQuantity')) || 0;
				var totalQuantity = itemRows.reduce(function (total, $row) {
					var quantityValue = $row.find('input[name$="[quantity]"]').val();
					return total + (parseMaterialQuantity(quantityValue) || 0);
				}, 0);
				itemRows.forEach(function ($row) {
					var $quantity = $row.find('input[name$="[quantity]"]');
					var quantityValue = $quantity.val();
					var hasQuantity = String(quantityValue).trim() !== '';
					var quantity = hasQuantity ? (parseMaterialQuantity(quantityValue) || 0) : 0;
					var remainingQuantity = availableQuantity - totalQuantity;
					var availableForRow = availableQuantity - (totalQuantity - quantity);
					$row.find('.available-quantity').html(availableQuantity.toFixed(2) + (hasQuantity ? '<span class="material-grid-remaining-quantity">' + Math.max(0, remainingQuantity).toFixed(2) + '</span>' : ''));
					$quantity.attr('data-available-quantity', Math.max(0, availableForRow));
				});
			});
		}
		function updateRowTotal($row) {
			var quantity = parseMaterialQuantity($row.find('input[name$="[quantity]"]').val()) || 0;
			var price = parseFloat($row.find('input[name$="[selling_price]"]').val()) || 0;
			var currency = $row.data('currency') || '';
			$row.find('.material-grid-currency').text(currency ? currency + ' ' : '');
			$row.find('.material-row-total').text((quantity * price).toFixed(2));
			refreshAvailableQuantities();
		}
		function setSelectFromSource($source, $target, replaceAllOptions) {
			if (!$source.length || !$target.length) return;
			var value = $source.val();
			var text = $source.find('option:selected').text();
			// Replace options while transferring between single and bulk modes.
			// This prevents Material and Asset options from being combined.
			var hasOnlyBlankOption = $target.find('option').length === 1 && !$target.find('option').first().val();
			if (replaceAllOptions || hasOnlyBlankOption) {
				$target.empty();
				$source.find('option').each(function () {
					$target.append(new Option(this.text, this.value, false, false));
				});
			}
			var hasOption = $target.find('option').filter(function () {
				return String(this.value) === String(value);
			}).length;
			if (!hasOption) $target.append(new Option(text, value, false, true));
			$target.val(value);

			// Keep the Semantic UI display in sync without firing its change event,
			// which would reload and overwrite the values being transferred.
			var $dropdown = $target.closest('.ui.dropdown');
			if (!$dropdown.length) $dropdown = $target.siblings('.ui.dropdown').first();
			if ($dropdown.length) {
				// Rebuild Semantic UI's generated menu from the incoming options.
				if (replaceAllOptions) {
					var $menu = $dropdown.children('.menu').empty();
					$target.find('option').each(function () {
						$menu.append($('<div class="item"></div>').attr('data-value', this.value).text(this.text));
					});
				}
				$dropdown.children('.text').text(text).removeClass('default');
				var $items = $dropdown.children('.menu').find('.item');
				var $selected = $items.filter(function () {
					return String($(this).attr('data-value')) === String(value);
				});
				if (!$selected.length && value !== null && value !== '') {
					$selected = $('<div class="item"></div>').attr('data-value', value).text(text);
					$dropdown.children('.menu').append($selected);
					$items = $items.add($selected);
				}
				$items.removeClass('active selected');
				$selected.addClass('active selected');
			}
		}
		function loadFirstGridRowIntoSingleEntry() {
			var $row = $rows.children('.material-grid-row').first();
			if (!$row.length) return;

			setSelectFromSource($('#material_grid_location_id'), $('#location_id'));
			setSelectFromSource($row.find('.material-grid-product'), $('#product'), true);
			setSelectFromSource($row.find('.material-grid-product-item'), $('#product_item'), true);

			var quantity = $row.find('input[name$="[quantity]"]').val();
			var sellPrice = $row.find('input[name$="[selling_price]"]').val();
			var currency = $row.data('currency') || '';
			var total = $row.find('.material-row-total').text();
			$('#product_quantity').val(quantity);
			$('#product_sell_price').val(sellPrice);
			$('#material_sn').val($row.find('textarea[name$="[serial_numbers]"]').val());
			var availableQuantity = parseFloat($row.data('availableQuantity'));
			$('#available_quantity').text(isNaN(availableQuantity) ? $row.find('.available-quantity').text() : availableQuantity.toFixed(2));
			$('#uom_id').val($row.find('input[name$="[uom_id]"]').val());
			$('#uom_label').text($row.find('.material-grid-uom-label').text());
			$('#inventory_item_id').val($row.data('inventoryItemId') || $row.find('.material-grid-product-item').val());
			$('#product_cost_price').val($row.data('costPrice') || '');
			$('#spcurrency, #cpcurrency').text(currency);
			$('#total').text(currency + total);
			$('#product_serial_numbers').val($row.data('productSerialNumbers') || '[]');
			$('#unittext').text($row.data('unitText') || '');
			if (typeof showHideSnNote === 'function') showHideSnNote($('#material_sn').val());
		}
		function loadSingleEntryIntoFirstGridRow() {
			var $row = $rows.children('.material-grid-row').first();
			var isNewGrid = !$row.length;
			if (isNewGrid) $row = addRow(false, false);

			setSelectFromSource($('#location_id'), $('#material_grid_location_id'));
			setSelectFromSource($('#product'), $row.find('.material-grid-product'));
			setSelectFromSource($('#product_item'), $row.find('.material-grid-product-item'));

			var quantity = $('#product_quantity').val();
			var availableQuantity = $('#available_quantity').text();
			$row.find('input[name$="[quantity]"]')
				.val(quantity)
				.attr('data-available-quantity', availableQuantity);
			$row.find('input[name$="[selling_price]"]').val($('#product_sell_price').val());
			$row.find('textarea[name$="[serial_numbers]"]').val($('#material_sn').val());
			$row.find('.available-quantity').text(availableQuantity);
			$row.find('input[name$="[uom_id]"]').val($('#uom_id').val());
			$row.find('.material-grid-uom-label').text($('#uom_label').text());
			$row.data('inventoryItemId', $('#inventory_item_id').val());
			$row.data('availableQuantity', parseFloat(String(availableQuantity).replace(/,/g, '')) || 0);
			$row.find('input[name$="[inventory_item_id]"]').val($('#inventory_item_id').val());
			$row.data('costPrice', $('#product_cost_price').val() || '');
			$row.data('currency', $('#spcurrency').text() || '');
			updateRowTotal($row);
			$row.data('productSerialNumbers', $('#product_serial_numbers').val() || '[]');
			$row.data('unitText', $('#unittext').text() || '');
			validateRowSerialNumbers($row);
		}
		function validateSingleQuantity() {
			var $quantity = $('#product_quantity');
			if (!validateNumericQuantity($quantity)) return false;
			var availableQuantity = parseFloat(($('#available_quantity').text() || '').replace(/,/g, ''));
			var quantity = parseMaterialQuantity($quantity.val());
			if (isNaN(availableQuantity) || isNaN(quantity) || quantity <= availableQuantity) return true;
			alert('Quantity cannot exceed the available quantity (' + availableQuantity + ').');
			$quantity.val(availableQuantity).focus();
			updateTotal('product_quantity', 'product_sell_price', 'total', 'spcurrency');
			return false;
		}
		function validateQuantity($quantity) {
			if (!validateNumericQuantity($quantity)) return false;
			var availableQuantity = parseFloat(($quantity.attr('data-available-quantity') || '').replace(/,/g, ''));
			var quantity = parseMaterialQuantity($quantity.val());
			if (isNaN(availableQuantity) || isNaN(quantity) || quantity <= availableQuantity) return true;
			alert('Quantity cannot exceed the available quantity (' + availableQuantity + ').');
			$quantity.val(availableQuantity).focus();
			updateRowTotal($quantity.closest('tr'));
			return false;
		}
		function updateGridDoneColumn() {
			$grid.find('.material-grid-done-column').toggle(isAssetLog());
		}
		function hasSingleEntryItems() {
			return $('#product_item option').filter(function () {
				return String(this.value || '') !== '';
			}).length > 0;
		}
		function updateMode() {
			updateGridDoneColumn();
			updateSingleEntryFields();
			if (!isInventoryLog()) {
				$toggle.hide();
				$grid.hide();
				$grid.find(':input').prop('disabled', true);
				$toggle.attr('aria-pressed', 'false');
				return;
			}
			var canUseBulkEntry = hasSingleEntryItems();
			$toggle.toggle(canUseBulkEntry);
			if (!canUseBulkEntry) {
				$toggle.attr('aria-pressed', 'false');
				$grid.hide();
				$grid.find(':input').prop('disabled', true);
				$single.show();
				return;
			}
			if ($toggle.attr('aria-pressed') === 'true') {
				$single.hide();
				$grid.show();
				ensureDefaultGridRows();
				$grid.find(':input').prop('disabled', false);
			} else {
				$grid.hide();
				// Hidden rows must not select the bulk backend after returning to
				// single-entry mode. Disabled controls are omitted from form data.
				$grid.find(':input').prop('disabled', true);
				$single.show();
			}
		}

		$(document).on('change', '#log_type', function () {
			$rows.empty();
			updateMode();
			if (isInventoryLog() && $toggle.attr('aria-pressed') !== 'true') reloadSingleEntryProducts();
		});
		$(document).on('change', '#product_item', updateSingleUomLabel);
		$(document).on('options:updated', '#product_item', updateMode);
		$(document).on('change', '#product_quantity', validateSingleQuantity);
		$toggle.on('click', function (event) {
			event.preventDefault();
			var $button = $(this);
			var isBulkEntry = $button.attr('aria-pressed') === 'true';
			if (isBulkEntry) {
				loadFirstGridRowIntoSingleEntry();
			} else {
				loadSingleEntryIntoFirstGridRow();
			}
			$button.attr('aria-pressed', !isBulkEntry);
			updateMode();
		});
		$singleToggle.on('click', function (event) {
			event.preventDefault();
			loadFirstGridRowIntoSingleEntry();
			$toggle.attr('aria-pressed', 'false');
			updateMode();
		});

		$('#material_grid_location_id').on('change', function () { $rows.children().each(function () { loadItems($(this)); }); });
		$('.add-material-grid-row').on('click', function (event) { event.preventDefault(); addRow(); });
		$rows.on('input', 'input[name$="[quantity]"], input[name$="[selling_price]"]', function () {
			markRowEntered($(this).closest('tr'));
			updateRowTotal($(this).closest('tr'));
		});
		$rows.on('change', 'input[name$="[quantity]"]', function () {
			validateQuantity($(this));
		});
		$('#product_quantity').closest('form').on('submit.materialQuantity', function () {
			if ($toggle.attr('aria-pressed') !== 'true') return validateSingleQuantity();
			var isValid = true;
			$rows.find('input[name$="[quantity]"]:enabled').each(function () {
				var $quantity = $(this);
				if (String($quantity.val()).trim() !== '' && !validateQuantity($quantity)) {
					isValid = false;
					return false;
				}
			});
			return isValid;
		});
		$rows.on('input change', 'textarea[name$="[serial_numbers]"]', function () {
			markRowEntered($(this).closest('tr'));
			validateRowSerialNumbers($(this).closest('tr'));
		});
		$rows.on('click', '.material-grid-remove', function (event) {
			event.preventDefault();
			var $row = $(this).closest('tr');
			if ($row.is(':first-child') || !window.confirm($(this).data('confirmMessage'))) return;
			$row.remove();
		});
		updateMode();
	});
