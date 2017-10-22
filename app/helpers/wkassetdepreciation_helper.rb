module WkassetdepreciationHelper
	include WktimeHelper
	include WkinventoryHelper
	include WkpayrollHelper
	include WkassetHelper
	include WkinvoiceHelper
	include WkbillingHelper
	
	def previewOrSaveDepreciation(startDate, endDate, assetId, isPreview)
		depreciationFreq = Setting.plugin_redmine_wktime['wktime_depreciation_frequency']
		depFreqValue = getFrequencyMonth(depreciationFreq)
		depreciationArr = Array.new 
		finacialPeriodArr = getFinancialPeriodArray(startDate, endDate, depreciationFreq)
		unless assetId.blank?
			assetEntries = WkInventoryItem.where(:id => assetId)
		else
			assetEntries = WkInventoryItem.asset.joins(:asset_property).where("wk_asset_properties.asset_type = ?", 'O')
		end
		errorMsg = ""
		localCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		# depLedgerId = 28 # This value should be get from settings
		assetEntries.each do |entry|
			assetProduct = entry.product_item.product
			depreciationRate = assetProduct.depreciation_rate
			depreciationType = Setting.plugin_redmine_wktime['wktime_depreciation_type'] #assetProduct.depreciation_type
			assetLedgerId = assetProduct.ledger_id
			unless depreciationRate.blank? || depreciationType.blank?
				finacialPeriodArr.each do|finacialPeriod|
					currentAssetVal = getCurrentAssetValue(entry, finacialPeriod[1])
					assetPrice = entry.cost_price + entry.over_head_price
					#sourceAmount = depreciationType != 'SL' ? currentAssetVal : (entry.cost_price + entry.over_head_price)
					depreciationAmt = getDepreciationAmount(depreciationType, depreciationRate, depFreqValue, currentAssetVal, assetPrice)
					depreciation = WkAssetDepreciation.where(:inventory_item_id => entry.id, :depreciation_date => finacialPeriod[1]).first_or_initialize(:depreciation_date => finacialPeriod[1], :inventory_item_id => entry.id)
					depreciation.actual_amount = currentAssetVal
					depreciation.depreciation_amount = depreciationAmt
					depreciation.currency = localCurrency
					unless isPreview
						if depreciation.save
							postDepreciationToAccouning(depreciation, assetLedgerId)
							# if true #autoPostGL('depreciation') Should get from settings
								# transAmountArr = [{assetLedgerId => depreciationAmt}, {depLedgerId => depreciationAmt}]
								# transId = depreciation.gl_transaction.blank? ? nil : depreciation.gl_transaction.id
								# glTransaction = postToGlTransaction('depreciation', transId, depreciation.depreciation_date, transAmountArr, depreciation.currency, nil, nil)
								# unless glTransaction.blank?
									# depreciation.gl_transaction_id = glTransaction.id
									# depreciation.save
								# end		
							# end
						else
							errorMsg = depreciation.errors.full_messages.join('\n')		
						end
					else
						depreciationArr << depreciation
					end
				end
			end
		end
		if assetEntries[0].blank?
			errorMsg = l(:error_wktime_save_nothing)
		end
		depreciationArr << errorMsg unless errorMsg.blank? || depreciationArr[0].blank?
		depreciationArr
	end
	
	def postDepreciationToAccouning(depreciation, assetLedgerId)
		depLedgerId = getSettingCfId('wktime_depreciation_ledger')
		if autoPostGL('inventory') && depLedgerId > 0
			transAmountArr = [{assetLedgerId => depreciation.depreciation_amount}, {depLedgerId => depreciation.depreciation_amount}]
			transId = depreciation.gl_transaction.blank? ? nil : depreciation.gl_transaction.id
			glTransaction = postToGlTransaction('depreciation', transId, depreciation.depreciation_date, transAmountArr, depreciation.currency, nil, nil)
			unless glTransaction.blank?
				depreciation.gl_transaction_id = glTransaction.id
				depreciation.save
			end		
		end
	end
	
	def getDepreciationAmount(depreciationType, depreciationRate, depFreqValue, currentAssetVal, assetPrice)
		sourceAmount = 0
		case depreciationType
		when 'SL'
			sourceAmount = assetPrice
		when 'WDV'
			sourceAmount = currentAssetVal
		end
		#sourceAmount = depreciationType != 'SL' ? currentAssetVal : (entry.cost_price + entry.over_head_price)
		depreciationAmt = (depreciationRate/12) * sourceAmount * depFreqValue
		depreciationAmt
	end
end
