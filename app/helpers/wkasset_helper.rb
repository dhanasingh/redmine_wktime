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
end
