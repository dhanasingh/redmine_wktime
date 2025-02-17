module WkassetHelper
include WktimeHelper

	def getRatePerHash(needBlank)
		ratePerHash = { 'h' => l(:label_hourly), 'd' => l(:label_daily), 'w' => l(:label_weekly), 'm' => l(:label_monthly), 'q' => l(:label_quarterly), 'sa' => l(:label_semi_annually), 'a' => l(:label_annually) }
		if needBlank
			ratePerHash = { '' => "", 'h' => l(:label_hourly), 'd' => l(:label_daily), 'w' => l(:label_weekly), 'm' => l(:label_monthly), 'q' => l(:label_quarterly), 'sa' => l(:label_semi_annually), 'a' => l(:label_annually) }
		end
		ratePerHash
	end

	def getAssetTypeHash(needBlank)
		assetType = { 'O'  => l(:label_own), 'R' =>  l(:label_rental), 'L' => l(:label_lease) }
		if needBlank
			assetType = { '' => "", 'O'  => l(:label_own), 'R' =>  l(:label_rental), 'L' => l(:label_lease) }
		end
		assetType
	end

	def getCurrentAssetValue(asset, period)
		latestDepreciation = WkAssetDepreciation.where("inventory_item_id = ? AND depreciation_date < ? AND depreciation_date NOT BETWEEN ? AND ? " , asset.id, period[1], period[0], period[1]).order(:depreciation_date =>:desc).first
		if latestDepreciation.blank?
			curVal = asset.asset_property.current_value.blank? ? (asset.cost_price + asset.over_head_price) : asset.asset_property.current_value
		else
			curVal = latestDepreciation.actual_amount - latestDepreciation.depreciation_amount
		end
		curVal = curVal.round(2) unless curVal.blank?
		curVal
	end

	def getRemainingDepreciation(entry, inventory_item_id)
		depreciationAmt = 0
		sourceAmount = Setting.plugin_redmine_wktime['wktime_depreciation_type'] == 'SL' ?  entry.current_value : entry.previous_value
		noOfdays = (Date.today - entry.depreciation_date).to_i
		leapYear = Date.today.leap? ? 366 : 365
		depreciationRate = WkInventoryItem.asset.joins(:asset_property, :product_item).where(:id => inventory_item_id ).order("wk_product_items.product_id").first
		rate = depreciationRate.product_item.product.depreciation_rate
		depreciationAmt = (rate/leapYear) * sourceAmount.to_f * noOfdays
		depreciationAmt
	end

	def getMaterialEntries(id)
		material_entries = WkMaterialEntry.get_material_entries(id)
		entries = {}
		entries[:data] = material_entries.map do |e|
			serial_number = e&.serial_number.map{|sn| sn.serial_number.to_s }
			editURL = url_for controller: 'timelog', action: 'edit', id: e.id, spent_type: getItemType == 'I' ? 'M' : 'A'
			{project: e&.project&.name, issue: e.issue.to_s, product: e.inventory_item&.product_item&.product&.name,
				brand: (e.inventory_item&.product_item&.brand&.name || ""), model: (e.inventory_item&.product_item&.product_model&.name || ""), serial_no: serial_number&.join(',').truncate_words(5, separator: ',') || '',
				currency: e.currency, selling_price: e.selling_price, quantity: e.quantity, icon: editURL
			}
		end
		entries[:header] = {
			project_name: l(:label_project), issue: l(:label_issue), product_name: l(:label_product), brand_name: l(:label_brand), product_model_name: l(:label_model), serial_no: l(:label_serial_number),
			currency: l(:field_currency), selling_price: l(:label_selling_price), quantity: l(:field_quantity), icon: ''}
		entries
	end

end
