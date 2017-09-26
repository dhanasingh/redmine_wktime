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
end
