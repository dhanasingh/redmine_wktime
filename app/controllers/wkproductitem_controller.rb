# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WkproductitemController < WkinventoryController

  menu_item :wkproduct
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy, :transfer, :updateTransfer]

  include WktimeHelper
  include WkgltransactionHelper
  include WkpayrollHelper
  include WkassetHelper
  include WkshipmentHelper
  include WkproductitemHelper

	def index

		sort_init 'id', 'asc'
		sort_update 'product_name' => "product_name",
					'brand_name' => "brand_name",
					'product_model_name' => "product_model_name",
					'product_attribute_name' => "product_attribute_name",
					'serial_number' => "iit.serial_number",
					'selling_price' => "iit.selling_price",
					'total_quantity' => "iit.total_quantity",
					'available_quantity' => "iit.available_quantity",
					'uom' => "uom_short_desc",
					'location_name' => "location_name",
					'parent_name' => "CASE WHEN pap.name IS NULL THEN ap.name ELSE pap.name END",
					'asset_name' => "CASE WHEN pap.name IS NULL THEN NULL ELSE ap.name END",
					'owner_type' => "ap.owner_type",
					'rate' => "ap.rate",
					'project_name' => "project_name"

		set_filter_session
		name = getSession(:name)
		availableItems = getSession(:available_items)
		productId = session[controller_name].try(:[], :product_id)
		brandId = session[controller_name].try(:[], :brand_id)
		locationId =session[controller_name].try(:[], :location_id)
		availabilityId =session[controller_name].try(:[], :availability)
		projectId =session[controller_name].try(:[], :project_id)
		isDisposed =session[controller_name].try(:[], :is_dispose)
		location = WkLocation.where(:is_default => 'true').first
		sqlwhere = ""
		selectStr = "select iit.id as inventory_item_id, pit.id as product_item_id, iit.product_item_id as inv_product_item_id, piit.product_item_id as parent_product_item_id, iit.status, p.name as product_name, b.name as brand_name, m.name as product_model_name, a.name as product_attribute_name, iit.serial_number, iit.currency, iit.selling_price, iit.total_quantity, iit.available_quantity, uom.short_desc as uom_short_desc, l.name as location_name, projects.name as project_name, (case when iit.product_type is null then p.product_type else iit.product_type end) as product_type, iit.is_loggable, ap.name as asset_name, piit.id as parent_id, pap.name as parent_name, ap.owner_type, ap.currency as asset_currency, ap.rate, ap.rate_per, ap.current_value, pcr.child_count, ap.is_disposed,ap.latitude as latitude, ap.longitude as longitude, iit.running_sn"
		if name.blank?
			unless productId.blank?
				sqlwhere = " AND pit.product_id = #{productId}"
			end
			unless brandId.blank? || brandId.to_i == 0
				sqlwhere = sqlwhere + " AND pit.brand_id = #{brandId}"
			end
		end

		if (!locationId.blank? || !location.blank?) && locationId != "0"
			location_id = !locationId.blank? ? locationId.to_i : location.id.to_i
			sqlwhere = sqlwhere + " AND iit.location_id = #{location_id}"
		end

		unless availabilityId.blank?
			if availabilityId == 'A'
				sqlwhere = sqlwhere + " AND ap.matterial_entry_id IS NULL"
			else
				sqlwhere = sqlwhere + " AND ap.matterial_entry_id IS NOT NULL"
			end
		end

		if projectId.blank?
			sqlwhere = sqlwhere + " AND iit.project_id IS NULL"
		elsif projectId != 'AP'
			sqlwhere = sqlwhere + " AND iit.project_id = #{projectId}"
		end

		unless name.blank?
			sqlwhere = sqlwhere + " AND (LOWER(p.name) like LOWER('%#{name}%') OR LOWER(b.name) like LOWER('%#{name}%') OR LOWER(m.name) like LOWER('%#{name}%'))"
		end
		unless availableItems.blank?
			sqlwhere = sqlwhere + " AND iit.available_quantity > 0 "
		end
		disposedCond = isDisposed.present? && isDisposed == "1"
		sqlwhere = sqlwhere + " AND (ap.is_disposed = #{booleanFormat(disposedCond)} #{!disposedCond ? 'OR ap.is_disposed IS NULL' : ''})" if getItemType == "A"

		sqlwhere = sqlwhere + " AND iit.parent_id IS NULL" if getItemType == "I"
		sqlwhere = sqlwhere + " AND pcr.child_count IS NULL" if getItemType != "I"

		sqlStr = getProductInventorySql + sqlwhere
		orderStr = " ORDER BY " + (sort_clause.present? ? sort_clause.first : " iit.id desc")
		respond_to do |format|
			format.html {
				findBySql(selectStr, sqlStr, orderStr)
			}
			format.api do
				@productInventory = WkProductItem.find_by_sql(selectStr + sqlStr + orderStr)
			end
			format.csv{
				entries = WkProductItem.find_by_sql(selectStr + sqlStr + orderStr)
				headers = getIventoryListHeader
				data = getCsvData(entries)
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: getItemType == "A" ? 'asset.csv' : 'productitem.csv')
			}
		end
	end

	def getProductInventorySql
		sqlStr = " from wk_product_items pit
		left outer join wk_inventory_items iit on iit.product_item_id = pit.id " + get_comp_condition('iit') + "
		left outer join wk_inventory_items piit on iit.parent_id = piit.id " + get_comp_condition('piit') + "
		left outer join (select count(parent_id) child_count, parent_id from wk_inventory_items" + get_comp_condition('wk_inventory_items', 'where') + " group by parent_id) pcr on pcr.parent_id = iit.id
		left outer join wk_products p on pit.product_id = p.id " + get_comp_condition('p') + "
		left outer join wk_brands b on pit.brand_id = b.id " + get_comp_condition('b') + "
		left outer join wk_product_models m on pit.product_model_id = m.id " + get_comp_condition('m') + "
		left outer join wk_product_attributes a on iit.product_attribute_id = a.id " + get_comp_condition('a') + "
		left outer join wk_locations l on iit.location_id = l.id " + get_comp_condition('l') + "
		left outer join projects on iit.project_id = projects.id " + get_comp_condition('projects') + "
		left outer join wk_mesure_units uom on iit.uom_id = uom.id " + get_comp_condition('uom') + "
		left outer join wk_asset_properties ap on ap.inventory_item_id = iit.id " + get_comp_condition('ap') + "
		left outer join wk_asset_properties pap on pap.inventory_item_id = piit.id " + get_comp_condition('pap') + "
		where ((case when iit.product_type is null then p.product_type else iit.product_type end) = '#{getItemType}' OR (case when iit.product_type is null then p.product_type else iit.product_type end) IS NULL)  " + get_comp_condition('pit')
		sqlStr
	end

	def edit
	    @productItem = nil
		@inventoryItem = nil
		@parentEntry = nil
		@newItem = to_boolean(params[:newItem])
	  if params[:product_item_id].present?
		   @productItem = WkProductItem.find(params[:product_item_id])
		end
		if params[:inventory_item_id].present?
		   @inventoryItem = WkInventoryItem.find(params[:inventory_item_id])
		   @productItem = WkProductItem.find(@inventoryItem.product_item_id) if params[:product_item_id].blank?
			 @lastDepr = WkAssetDepreciation.lastDepr(params[:inventory_item_id]).first
		end
		unless params[:parentId].blank?
			@parentEntry = WkInventoryItem.find(params[:parentId])
		end
		@assembledComponent = WkInventoryItem.get_assembled_component(@inventoryItem&.id) if @inventoryItem.present?
	end

	def transfer
		unless params[:inventory_item_id].blank?
		   @transferItem = WkInventoryItem.find(params[:inventory_item_id])
		end
	end

	def update
		barndId = params[:brand_id].blank? ? nil : params[:brand_id]
		modelId = params[:product_model_id].blank? ? nil : params[:product_model_id]
		existingItem = WkProductItem.where(:product_id => params[:product_id], :brand_id => barndId, :product_model_id => modelId)
		if params[:product_item_id].blank?
			productItem = WkProductItem.new
			productItem = existingItem[0] unless existingItem[0].blank?
		else
			productItem = existingItem[0]
			productItem = WkProductItem.new if existingItem[0].blank?
		end
		productItem.part_number = params[:part_number]
		productItem.product_id = params[:product_id]
		productItem.brand_id = params[:brand_id]
		productItem.product_model_id = params[:product_model_id]
		if productItem.save()
			inventoryItem = nil
			if !params[:available_quantity].blank?
				locationId = params[:location_id].to_i
				projId = params[:project_id]
				unless params[:parent_id].blank?
					invItem = WkInventoryItem.find(params[:parent_id].to_i)
					locationId = invItem.location_id
					projId = invItem.project_id
				end
				inventoryItem = updateInventoryItem(productItem.id, locationId,projId)
			elsif !params[:inventory_item_id].blank?
				inventoryItem = WkInventoryItem.find(params[:inventory_item_id].to_i)
				inventoryItem.selling_price = params[:selling_price]
				inventoryItem.is_loggable = params[:is_loggable]
				inventoryItem.save
			end
			unless inventoryItem.blank?
				assetProperty = updateAssetProperty(inventoryItem) if inventoryItem.product_type != 'I' #!inventoryItem.blank? &&
				assetAccountingHash = Hash.new
				assetValue = 0
				if inventoryItem.product_type == 'A'
						assetValue = (inventoryItem.total_quantity*(inventoryItem.cost_price+inventoryItem.over_head_price))
						# assetTotal = assetTotal + assetValue
						accountingLedger = WkProductItem.find(inventoryItem.product_item_id).product.ledger_id
						ledgerId = ((!accountingLedger.blank? && accountingLedger > 0) ? accountingLedger : getSettingCfId("inventory_db_ledger"))
						assetAccountingHash[ledgerId] = assetValue
				end
				postShipmentAccounting(inventoryItem.shipment, assetAccountingHash, assetValue)
			end
		end
		errorMsg = productItem.errors.full_messages.join("<br>")
		respond_to do |format|
			format.html {
				if errorMsg.blank?
					saveAssembledItem(params[:assemble], inventoryItem) if params[:assemble].present?
					redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name
					flash[:notice] = l(:notice_successful_update)
				else
					redirect_to :controller => controller_name,:action => 'edit' , :product_item_id => params[:product_item_id], :inventory_item_id => params[:inventory_item_id], :tab => controller_name
					flash[:error] = errorMsg
				end
			}
			format.api{
				if errorMsg.blank?
					render :plain => errorMsg, :layout => nil
				else
					@error_messages = errorMsg.split('\n')
					render :template => 'common/error_messages', :format => [:api], :status => :unprocessable_entity, :layout => nil
				end
			}
		end
  end

	def updateTransfer
		sourceItem = WkInventoryItem.find(params[:transfer_item_id].to_i)
		transferQty = (params[:total_quantity].blank? ? params[:available_quantity].to_i : params[:total_quantity].to_i)
		availQuantity = sourceItem.available_quantity - transferQty
		unless availQuantity < 0 || transferQty <= 0
			if sourceItem.running_sn.present?
				org_sn_length = sourceItem.running_sn.length
				serial_number = (params[:running_sn].to_i + (transferQty -1).to_i).to_s.rjust(org_sn_length, '0')
				org_end_sn_no = ((sourceItem.running_sn.to_i) + ((sourceItem.available_quantity.to_i)-1)).to_s.rjust(org_sn_length, '0')
				if sourceItem.running_sn == params[:running_sn]
					sourceItem.available_quantity = availQuantity
					sourceItem.running_sn = (serial_number.to_i + 1).to_s.rjust(org_sn_length, '0')
				elsif serial_number != org_end_sn_no
					split_quantity = 0
					source_quantity = 0
					splitItem = sourceItem.dup
					new_sn = ((serial_number.to_i) +1).to_s.rjust(org_sn_length, '0')
					splitItem.running_sn = new_sn
					(sourceItem.running_sn.to_i..((params[:running_sn].to_i - 1).to_s.rjust(org_sn_length, '0').to_i)).each{ source_quantity += 1;}
					(new_sn.to_i..org_end_sn_no.to_i).each{ split_quantity += 1;}
					sourceItem.available_quantity = source_quantity
					splitItem.available_quantity = split_quantity
					splitItem.save()
				else
					sourceItem.available_quantity = availQuantity
				end
			else
				sourceItem.available_quantity = availQuantity
			end
			if sourceItem.save()
				targetItem = updateInventoryItem(params[:product_item_id].to_i, params[:location_id].to_i, params[:project_id])
				if sourceItem.product_type == 'A'
					depreciationFreq = Setting.plugin_redmine_wktime['wktime_depreciation_frequency']
					finacialPeriodArr = getFinancialPeriodArray(Date.today, Date.today, depreciationFreq, 1)
					finacialPeriod = finacialPeriodArr[0]
					targetAssetProp = sourceItem.asset_property.dup
					targetAssetProp.inventory_item_id = targetItem.id
					targetAssetProp.current_value = getCurrentAssetValue(sourceItem, finacialPeriod)
					targetAssetProp.save
				end
				redirect_to :controller => controller_name,:action => 'index', :tab => controller_name
				flash[:notice] = l(:notice_successful_update)
			else
				redirect_to :controller => controller_name,:action => 'index', :tab => controller_name
				flash[:error] = sourceItem.errors.full_messages.join("<br>")
			end
		else
			errorMsg = transferQty <= 0 ? l(:error_transfer_qty_greater_than_zero) : l(:error_avail_qty_great_than_trans_qty)
			redirect_to :controller => controller_name,:action => 'transfer', :tab => controller_name, :inventory_item_id => sourceItem.id
			flash[:error] = errorMsg
		end
	end

	def updateInventoryItem(productItemId, locationId, projId)
		sysCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		if params[:inventory_item_id].blank?
			inventoryItem = WkInventoryItem.new
			inventoryItem.product_type = params[:product_type].blank? ? getItemType : params[:product_type]
		else
			inventoryItem = WkInventoryItem.find(params[:inventory_item_id].to_i)
		end

		unless params[:transfer_item_id].blank?
			transferItem = WkInventoryItem.find(params[:transfer_item_id].to_i)
			inventoryItem = transferItem.dup
			inventoryItem.from_id = params[:transfer_item_id].to_i
			inventoryItem.supplier_invoice_id = nil
			inventoryItem.lock_version = 0
			inventoryItem.shipment_id = transferItem.shipment_id
			inventoryItem.org_over_head_price = ((inventoryItem.org_over_head_price / inventoryItem.total_quantity) * params[:available_quantity].to_i ).round(2) if inventoryItem.org_over_head_price.present?
			inventoryItem.over_head_price = params[:over_head_price]
		else
			inventoryItem.product_item_id = productItemId
			# inventoryItem.serial_number = params[:serial_number]
			inventoryItem.product_attribute_id = params[:product_attribute_id]
			if sysCurrency != params[:currency]
				inventoryItem.org_currency = params[:currency]
				inventoryItem.org_cost_price = params[:cost_price]
				inventoryItem.org_over_head_price = params[:over_head_price]
				inventoryItem.org_selling_price = params[:selling_price]
			end
			inventoryItem.currency = sysCurrency
			inventoryItem.cost_price = getExchangedAmount(params[:currency], params[:cost_price])
			inventoryItem.over_head_price = getExchangedAmount(params[:currency], params[:over_head_price])
			inventoryItem.is_loggable = params[:is_loggable]
		end
		inventoryItem.parent_id = params[:parent_id] unless params[:parent_id].blank?
		inventoryItem.notes = params[:notes]
		inventoryItem.selling_price = getExchangedAmount(params[:currency], params[:selling_price])
		inventoryItem.total_quantity = params[:total_quantity]
		inventoryItem.total_quantity = params[:available_quantity] if params[:total_quantity].blank?
		inventoryItem.available_quantity = params[:available_quantity]
		inventoryItem.status = inventoryItem.available_quantity == 0 ? 'c' : 'o'
		inventoryItem.uom_id = params[:uom_id].to_i
		inventoryItem.location_id = locationId if params[:location_id] != "0"
		inventoryItem.project_id = projId
		inventoryItem.serial_number = params[:serial_number]
		inventoryItem.running_sn = params[:running_sn]
		inventoryItem.save()
		updateShipment(inventoryItem) if inventoryItem.product_type == 'I'
		inventoryItem
	end

	def updateAssetProperty(inventoryItem)
		sysCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		if params[:asset_property_id].blank?
			assetProperty = WkAssetProperty.new
			updateShipment(inventoryItem)
			assetProperty.inventory_item_id = inventoryItem.id
		else
			assetProperty = inventoryItem.asset_property
		end
		assetProperty.name = params[:asset_name]
		assetProperty.rate = params[:rate]
		assetProperty.rate_per = params[:rate_per]
		assetProperty.current_value = params[:current_value]
		assetProperty.owner_type = params[:owner_type]
		if isChecked('asset_save_geo_location') && params[:save_current_location].to_i  == 1
			assetProperty.latitude = params[:latitude]
			assetProperty.longitude = params[:longitude]
		end
		assetProperty.save()
		assetProperty
	end

	def updateShipment(inventoryItem)
		wkShipmentObj = WkShipment.new
		wkShipmentObj.shipment_type = 'N'
		wkShipmentObj.shipment_date = Date.today
		wkShipmentObj.serial_number = params[:serial_number]
		wkShipmentObj.save()
		inventoryItem.shipment_id = wkShipmentObj.id
		inventoryItem.save()
	end

	def destroy
		inventoryItem = nil
		productItem = WkProductItem.find(params[:product_item_id].to_i)
		unless params[:inventory_item_id].blank?
			inventoryItem = WkInventoryItem.find(params[:inventory_item_id].to_i)
			shipment = inventoryItem.shipment
			if inventoryItem.destroy
				invCount = productItem.inventory_items.count
				shipInvCount = 0
				shipInvCount = shipment.inventory_items.count unless shipment.blank?
				productItem.destroy unless invCount>0
				shipment.destroy unless shipInvCount>0 || shipment.blank?
				flash[:notice] = l(:notice_successful_delete)
			else
				flash[:error] = inventoryItem.errors.full_messages.join("<br>")
			end
		else
			if productItem.destroy
				flash[:notice] = l(:notice_successful_delete)
			else
				flash[:error] = inventoryItem.errors.full_messages.join("<br>")
			end
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end

	def get_material_entries
		entries = getMaterialEntries(params[:inventory_item_id])
		render json: {data: entries[:data], header: entries[:header]}
	end

	def set_filter_session(filters=nil, filterParams={})
		filters = [:product_id, :brand_id, :location_id, :availability, :project_id, :is_dispose, :show_on_map, :name, :available_items] if filters.blank?
		super(filters, filterParams)
	end

	def setLimitAndOffset
		if api_request?
			@offset, @limit = api_offset_and_limit
			if !params[:limit].blank?
				@limit = params[:limit]
			end
			if !params[:offset].blank?
				@offset = params[:offset]
			end
		else
			@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			@limit = @entry_pages.per_page
			@offset = @entry_pages.offset
		end
	end

	def findBySql(selectStr, query, orderStr)
		@entry_count = findCountBySql(query, WkProductItem)
		setLimitAndOffset()
		rangeStr = formPaginationCondition()
		@productInventory = WkProductItem.find_by_sql(selectStr + query + orderStr + rangeStr)
	end

	def formPaginationCondition
		rangeStr = ""
		if ActiveRecord::Base.connection.adapter_name == 'SQLServer'
			rangeStr = " OFFSET " + @offset.to_s + " ROWS FETCH NEXT " + @limit.to_s + " ROWS ONLY "
		else
			rangeStr = " LIMIT " + @limit.to_s +	" OFFSET " + @offset.to_s
		end
		rangeStr
	end

	def getItemType
		'I'
	end

	def showAssetProperties
		false
	end

	def newItemLabel
		l(:label_new_product_item)
	end

	def newAsset
		false
	end

	def editItemLabel
		l(:label_edit_product_item)
	end

	def getIventoryListHeader
		headerHash = { 'project_name' => l(:label_project), 'product_name' => l(:label_product), 'brand_name' => l(:label_brand), 'product_model_name' => l(:label_model), 'product_attribute_name' => l(:label_attribute), 'serial_number' => l(:label_serial_number), 'currency' => l(:field_currency), 'selling_price' => l(:label_selling_price), 'total_quantity' => l(:label_total_quantity), 'available_quantity' => l(:label_available_quantity), 'uom_short_desc' => l(:label_uom), 'location_name' => l(:field_location) }
	end

	def showProductItem
		true
	end

	def showAdditionalInfo
		true
	end

	def showInventoryFields
		true
	end

	def lblInventory
		l(:label_inventory)
	end

	def newcomponentLbl
		l(:label_new_component)
	end

	def getCsvData(entries)
		data = entries.map{|entry| {project_name: entry['project_name'] || '', product_name: entry['product_name'] || '', brand_name: entry['brand_name'] || '', product_model_name: entry['product_model_name'] || '', product_attribute_name: entry['product_attribute_name'] || '', serial_number: entry['serial_number'] || '', currency: entry['currency'] || '', selling_price: entry['selling_price'] || '', total_quantity: entry['total_quantity'] || '', available_quantity: entry['available_quantity'] || '', uom_short_desc: entry['uom_short_desc'] || '', location_name: entry['location_name'] || ''}
		}
	end

	def sectionHeader
		l(:label_components)
	end

	def editcomponentLbl
		l(:label_edit_component)
	end

	def getItemDetails
		item = WkInventoryItem.find(params[:id])
		render json: {item: item}
	end
end