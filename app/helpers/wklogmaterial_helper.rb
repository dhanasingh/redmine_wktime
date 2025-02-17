module WklogmaterialHelper
	include ApplicationHelper
	include WktimeHelper
	include WkassetHelper

	def getLogHash
		spentTypeHash = {}
		spentTypeHash.store('T', l(:label_wktime)) if isChecked('wktime_enable_time_module')
		spentTypeHash.store('E', l(:label_wkexpense)) if isChecked('wktime_enable_expense_module')
		if isChecked('wktime_enable_inventory_module')
			spentTypeHash.store('M', l(:label_material))
			spentTypeHash.store('A', l(:label_asset))
		end
		additionalProducts = call_hook :additional_spent_type
		unless additionalProducts.blank?
			if additionalProducts.is_a?(Array)
				additionalProducts.each do | hsh |
					spentTypeHash =  spentTypeHash.merge(hsh)
				end
			else
				mergeHash = eval(additionalProducts)
				spentTypeHash =  spentTypeHash.merge(mergeHash)
			end
		end

		spentTypeHash
	end

	def getProductCatagoryArray(model, categoryId, needBlank)
		if categoryId.blank?
			pctCatArr = model.all.order(:name).pluck(:name, :id)
		else
			pctCatArr = model.all.order(:name).pluck(:name, :id) #where(:category_id => categoryId).order(:name).pluck(:name, :id)
		end
		pctCatArr.unshift(["",'']) if needBlank
		pctCatArr
	end

	def getProductArray(model, productId, productType, needBlank)
		if productId.blank? && productType.blank?
			pdtArr = model.all.order(:name).pluck(:name, :id)
		elsif !productId.blank? && !productType.blank?
			pdtArr = model.where(:id => productId.to_i).where("product_type = ? OR product_type is null", productType).pluck(:name, :id)
		elsif !productId.blank?
			pdtArr = model.where(:id => productId.to_i).pluck(:name, :id)
		elsif !productType.blank?
			pdtArr = model.where("product_type = ? OR product_type is null", productType).pluck(:name, :id)
		end
		pdtArr.unshift(["",'']) if needBlank
		pdtArr
	end

	def getProductBrandArray(productId, needBlank)
		pctArr = WkProduct.find(productId)
		pctBrandArr = pctArr.brands.order(:name).pluck(:name, :id)
		pctBrandArr.unshift(["",'']) if needBlank
		pctBrandArr
	end

	def getProductItemArr(productId, needBlank)
		pItemObj = WkProductItem.where(:product_id => productId)
		pctItemArr = pItemObj.collect{|i| [ "#{i.part_number} - #{i.product_attribute.name} - #{i.currency}#{i.selling_price} ", i.id ] }
		pctItemArr.unshift(["",'']) if needBlank
		pctItemArr
	end

	def mergePItemInvItemQuery(productId, logType, locationId)

		sqlQuery = "select it.id, pi.product_id, pi.brand_id, wap.name as asset_name, wap.rate, wap.rate_per, wb.name as brand_name, it.product_attribute_id, pi.product_model_id, wpm.name as product_model_name, pi.part_number, it.cost_price, it.selling_price, it.currency, it.available_quantity, it.uom_id, it.serial_number, it.running_sn from wk_inventory_items it
		left outer join wk_product_items pi on pi.id = it.product_item_id "+get_comp_cond('pi')+"
		left outer join wk_brands wb on wb.id = pi.brand_id "+get_comp_cond('wb')+"
		left outer join wk_product_models wpm on wpm.id = pi.product_model_id "+get_comp_cond('wpm')+"
		left outer join wk_asset_properties wap on wap.inventory_item_id = it.id "+get_comp_cond('wap')+"
		left outer join wk_material_entries wme on wme.id = wap.matterial_entry_id "+get_comp_cond('wme')+"
		 where  it.available_quantity > 0 "+get_comp_cond('it')
		sqlQuery = sqlQuery  + " and pi.product_id = #{productId} " unless productId.blank?
		sqlQuery = sqlQuery  + " and it.product_type = '#{logType}' " unless logType.blank?
		sqlQuery = sqlQuery + " and (wap.matterial_entry_id is null or wme.user_id = #{User.current.id}) "
		sqlQuery = sqlQuery + " and it.location_id = #{locationId} " unless locationId.blank?
		sqlQuery = sqlQuery + " and it.is_loggable = #{booleanFormat(true)} " if logType == 'A'
		sqlQuery = sqlQuery + " order by wb.name, wpm.name, it.serial_number"
		pctObj = WkInventoryItem.find_by_sql(sqlQuery)
		pctObj
	end

	def getPdtItemArr(productId, needBlank, logType, locationId)
		pctObj = mergePItemInvItemQuery(productId, logType, locationId)
		pctArr = Array.new
		rateperhash = getRatePerHash(false)
		pctObj.each do | entry|
			attributeName = entry.product_attribute.blank? ? "" : entry.product_attribute.name
			if logType == 'A'

				pctArr << [(entry.asset_name.to_s() + ' - ' + entry.rate.to_s() + ' - ' + rateperhash[entry.rate_per].to_s()), entry.id.to_s() ]
			else
				pctArr <<  [(entry.brand_name.to_s() +' - '+ entry.product_model_name.to_s() +' - '+ attributeName + ' - '+ entry.part_number.to_s() +' - '+  (entry.currency.to_s() + ' ' +  entry.selling_price.to_s()) +' - '+ (entry.serial_number.to_s() + entry.running_sn.to_s()) ),  entry.id.to_s()]
			end
		end
		pctArr.unshift(["",'']) if needBlank
		pctArr
	end

	def getUOMArray(uomId, needBlank)
		uomArr = Array.new
		if uomId.blank?
			uomArr = WkMesureUnit.all.pluck(:name, :id)
		else
			uomArr = WkMesureUnit.find(uomId).pluck(:name, :id)
		end
		uomArr.unshift(["",'']) if needBlank
		uomArr
	end

	def updateParentInventoryItem(inventoryItemId, productQuantity, materialQuantity)
		inventoryItemObj = WkInventoryItem.find(inventoryItemId)
		if materialQuantity.blank?
			totalAvlQty = inventoryItemObj.available_quantity
			materialQuantity = 0
		else
			totalAvlQty = inventoryItemObj.available_quantity + materialQuantity
		end

		if  totalAvlQty >= productQuantity
			qtyVal = materialQuantity - productQuantity
			inventoryItemObj.incrementAvaQty(qtyVal)
			inventoryItemObj.save
		end
		inventoryItemObj
	end

	def saveMatterialEntries(id, projectId, userId, issueId, quantity, sellingPrice, currency, activityId, spentOn, invItemId, uomId)
		if id.blank?
			matterialObj = WkMaterialEntry.new
		else
			matterialObj = WkMaterialEntry.find(id.to_i)
		end
		matterialObj.project_id = projectId
		matterialObj.user_id = userId
		matterialObj.issue_id = issueId
		matterialObj.quantity = quantity
		matterialObj.selling_price = sellingPrice
		matterialObj.currency = currency
		matterialObj.activity_id = activityId
		matterialObj.spent_on = spentOn
		matterialObj.inventory_item_id = invItemId
		matterialObj.uom_id = uomId
		matterialObj.save
		matterialObj
	end

	def getProductSNs(id)
		serialNos = []
		inventory_item = WkInventoryItem.find(id)
		if inventory_item.present? && inventory_item.running_sn.present?
			serial_number = inventory_item&.serial_number
			running_sn = inventory_item&.running_sn
			total_quantity = inventory_item&.total_quantity
			org_sn_length = running_sn&.length;
			for i in 1..total_quantity
				serialNos << serial_number.to_s + running_sn.to_s
				running_sn = running_sn.to_i + 1
				running_sn = running_sn.to_s.rjust(org_sn_length, '0') if running_sn.to_s.length < org_sn_length
			end
		end
		serialNos
	end

	def getLogTypeName
		entry = {'T' => 'time_entry', 'E' => 'wk_expense_entry', 'M' => 'wk_material_entry', 'A' => 'wk_material_entry'}
		hookType = call_hook(:additional_type)
		entry[hookType] = 'wk_material_entry' if hookType.present?
		entry
	end

	def get_item_details_url(itemId, spentType)
		productItemId = WkInventoryItem.find(itemId)&.product_item_id
		url = {action: 'edit', inventory_item_id: itemId, product_item_id: productItemId}
		if spentType == 'M'
			url[:controller] = 'wkproductitem'
		elsif spentType == 'A'
			url[:controller] = 'wkasset'
		else
			call_hook(:get_inventory_url, {url: url, spentType: spentType})
		end
		url
	end

	def saveConsumedSN(serial_nos, entry)
		serial_nos.each do |sn|
			WkConsumedItems.where(id: sn["id"]).delete_all() if sn["is_delete"].present? && sn["id"].present?
			if sn["id"].blank? && !sn["is_delete"]
				materialSN = WkConsumedItems.new
				materialSN.consumer_id = entry.id
				materialSN.consumer_type = entry.class.name
				materialSN.serial_number = sn["serial_number"]
				materialSN.save
			end
		end
	end
end
