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
			assetEntries = WkInventoryItem.joins(:product_item).where(:id => assetId).order("wk_product_items.product_id")
		else
			assetEntries = WkInventoryItem.asset.joins(:asset_property, :product_item).where("wk_asset_properties.owner_type = ?", 'O').order("wk_product_items.product_id")
		end
		errorMsg = ""
		localCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		invCrLedger = getSettingCfId("inventory_cr_ledger")
		depreciationType = Setting.plugin_redmine_wktime['wktime_depreciation_type'] 
		finacialPeriodArr.each do|finacialPeriod|
			#lastProductId = nil
			depreciationIds = Array.new
			glTransIds = Array.new
			productDepAmtHash = Hash.new
			#assetLedgerId = nil
			#depreciationRate = nil
			totalDepAmt = 0
			assetEntries.each do |entry|
				assetProduct = entry.product_item.product
				#if lastProductId != assetProduct.id
				depreciationRate = assetProduct.depreciation_rate
				assetLedgerId = assetProduct.ledger_id
				#end
				unless depreciationRate.blank? || depreciationType.blank?
					currentAssetVal = getCurrentAssetValue(entry, finacialPeriod[1])
					assetPrice = entry.cost_price + entry.over_head_price
					depreciationAmt = getDepreciationAmount(depreciationType, depreciationRate, depFreqValue, currentAssetVal, assetPrice)
					depreciation = WkAssetDepreciation.where(:inventory_item_id => entry.id, :depreciation_date => finacialPeriod[1]).first_or_initialize(:depreciation_date => finacialPeriod[1], :inventory_item_id => entry.id)
					depreciation.actual_amount = currentAssetVal
					depreciation.depreciation_amount = depreciationAmt
					depreciation.currency = localCurrency
					unless isPreview
						if depreciation.save
							unless assetLedgerId.blank?
								depreciationIds << depreciation.id
								glTransIds << depreciation.gl_transaction_id unless depreciation.gl_transaction_id.blank?
								totalDepAmt = totalDepAmt + depreciation.depreciation_amount
								productDepAmtHash[assetLedgerId] = productDepAmtHash[assetLedgerId].blank? ? depreciation.depreciation_amount : (productDepAmtHash[assetLedgerId] + depreciation.depreciation_amount)
							end
							# postDepreciationToAccouning(depreciation, assetLedgerId)
						else
							errorMsg = depreciation.errors.full_messages.join('\n')		
						end
					else
						depreciationArr << depreciation
					end
				end
				#lastProductId = assetProduct.id
			end
			glTransIds.uniq!
			postDepreciationToAccouning(depreciationIds, glTransIds, finacialPeriod[1], productDepAmtHash, totalDepAmt, localCurrency)
		end
		if assetEntries[0].blank?
			errorMsg = l(:error_wktime_save_nothing)
		end
		depreciationArr << errorMsg unless errorMsg.blank? || depreciationArr[0].blank?
		depreciationArr
	end
	
	def postDepreciationToAccouning(depIds, glTransIds, depDate, productDepAmtHash, totalDepAmt, currency)
		depLedgerId = getSettingCfId('wktime_depreciation_ledger')
		if autoPostGL('inventory') && depLedgerId > 0
			transAmountArr = [productDepAmtHash, {depLedgerId => totalDepAmt}]
			transId = glTransIds[0].blank? ? nil : glTransIds[0]
			glTransaction = postToGlTransaction('depreciation', transId, depDate, transAmountArr, currency, nil, nil)
			unless glTransaction.blank?
				WkAssetDepreciation.where(:id => depIds).update_all(gl_transaction_id: glTransaction.id)
				# depreciation.gl_transaction_id = glTransaction.id
				# depreciation.save
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
