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
		finacialPeriodArr = getFinancialPeriodArray(startDate, endDate, depreciationFreq, 1)
		unless assetId.blank?
			assetEntries = WkInventoryItem.asset.joins(:asset_property, :product_item).where(:id => assetId, :wk_asset_properties => {:owner_type => 'O'}).order("wk_product_items.product_id").where("wk_inventory_items.available_quantity > ?", 0)
		else
			assetEntries = WkInventoryItem.asset.joins(:asset_property, :product_item).where("wk_asset_properties.owner_type = ? and wk_inventory_items.available_quantity > ? ", 'O', 0).order("wk_product_items.product_id")
		end
		errorMsg = ""
		localCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		invCrLedger = getSettingCfId("inventory_cr_ledger")
		depreciationType = Setting.plugin_redmine_wktime['wktime_depreciation_type'] 
		finacialPeriodArr.each do|finacialPeriod|
			depreciationIds = Array.new
			glTransIds = Array.new
			productDepAmtHash = Hash.new
			totalDepAmt = 0
			assetEntries.each do |entry|
				if entry.shipment.shipment_date > finacialPeriod[1]
					next
				end
				assetProduct = entry.product_item.product				
				depreciationRate = assetProduct.depreciation_rate
				assetLedgerId = assetProduct.ledger_id
				unless depreciationRate.blank? || depreciationType.blank?
					currentAssetVal = getCurrentAssetValue(entry, finacialPeriod)
					assetPrice = entry.cost_price + entry.over_head_price
					depreciationAmt = getDepreciationAmount(depreciationType, depreciationRate, depFreqValue, currentAssetVal, assetPrice, entry.shipment.shipment_date, finacialPeriod)
					if depreciationAmt>0
						depreciation = WkAssetDepreciation.where(:inventory_item_id => entry.id, :depreciation_date => finacialPeriod[1]).first_or_initialize(:depreciation_date => finacialPeriod[1], :inventory_item_id => entry.id)
						depreciation.actual_amount = currentAssetVal
						depreciation.depreciation_amount = depreciationAmt
						depreciation.currency = localCurrency
						unless isPreview
							if depreciation.save
								WkAssetDepreciation.where(:inventory_item_id => entry.id, :depreciation_date => finacialPeriod[0] .. finacialPeriod[1]).where.not(:depreciation_date => finacialPeriod[1]).destroy_all
								unless assetLedgerId.blank?
									depreciationIds << depreciation.id
									glTransIds << depreciation.gl_transaction_id unless depreciation.gl_transaction_id.blank?
									totalDepAmt = totalDepAmt + depreciation.depreciation_amount
									productDepAmtHash[assetLedgerId] = productDepAmtHash[assetLedgerId].blank? ? depreciation.depreciation_amount : (productDepAmtHash[assetLedgerId] + depreciation.depreciation_amount)
								end
							else
								errorMsg = depreciation.errors.full_messages.join('\n')		
							end
						else
							depreciationArr << depreciation
						end
					end
				end
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
			end		
		end
	end
	
	def getDepreciationAmount(depreciationType, depreciationRate, depFreqValue, currentAssetVal, assetPrice, purchaseDate, finPeriod)
		sourceAmount = 0
		case depreciationType
		when 'SL'
			sourceAmount = assetPrice
		when 'WDV'
			sourceAmount = currentAssetVal
		end
		if purchaseDate.between?(finPeriod[0], finPeriod[1])
			noOfMonths = monthsBetween(purchaseDate, finPeriod[1])
			depFreqValue = noOfMonths
		end
		depreciationAmt = (depreciationRate/12) * sourceAmount * depFreqValue
		if depreciationAmt > currentAssetVal
			depreciationAmt = currentAssetVal
		end
		depreciationAmt
	end
	
	def monthsBetween(startDate, endDate)
		noOfDays = endDate - startDate
		noOfMonth = (noOfDays/30.0).round(0)
		noOfMonth
	end
end
