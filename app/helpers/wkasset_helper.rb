module WkassetHelper

	def getRatePerHash(needBlank)
		ratePerHash = { 'H'  => l(:label_hourly), 'D' =>  l(:label_daily), 'M' => l(:label_monthly) }
		if needBlank
			ratePerHash = { '' => "", 'H'  => l(:label_hourly), 'D' =>  l(:label_daily), 'M' => l(:label_monthly) }
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
	
	def getCurrentAssetValue(asset)
		latestDepreciation = WkAssetDepreciation.where(:inventory_item_id => asset.id).order(:depreciation_date =>:desc).first
		if latestDepreciation.blank?
			curVal = asset.asset_property.current_value.blank? ? (asset.cost_price + asset.over_head_price) : asset.asset_property.current_value
		else
			curVal = latestDepreciation.actual_amount - latestDepreciation.depreciation_amount
		end
		curVal
	end
end
