# ERPmine - ERP for service industry
# Copyright (C) 2011-2021  Adhi software pvt ltd
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

class WkdeliveryController < WkinventoryController

  menu_item :wkproduct
	before_action :require_login

	include WkreportHelper
	include WkdeliveryHelper

	def index
		sort_init 'shipment_date', 'desc'
		sort_update 'serial_number' => "#{WkShipment.table_name}.serial_number",
					'shipment_name' => "#{WkShipment.table_name}.parent_type",
					'shipment_date' => "#{WkShipment.table_name}.shipment_date"

		set_filter_session
		retrieve_date_range
		sqlwhere = " wk_shipments.shipment_type = '#{getShipmentType}' "
		filter_type = session[controller_name].try(:[], :polymorphic_filter)
		contact_id = session[controller_name].try(:[], :contact_id)
		account_id = session[controller_name].try(:[], :account_id)
		projectId = session[controller_name].try(:[], :project_id)
		delivery_status =session[controller_name].try(:[], :delivery_status)
		parentType = ""
		parentId = ""
		delivery = WkShipment.includes(:delivery_items)
		if filter_type == '2' && !contact_id.blank?
			parentType = 'WkCrmContact'
			parentId = 	contact_id
		elsif filter_type == '2' && contact_id.blank?
			parentType = 'WkCrmContact'
		end

		if filter_type == '3' && !account_id.blank?
			parentType =  'WkAccount'
			parentId = 	account_id
		elsif filter_type == '3' && account_id.blank?
			parentType =  'WkAccount'
		end

		unless parentId.blank?
			sqlwhere = sqlwhere + " and wk_shipments.parent_id = '#{parentId}' "
		end

		unless parentType.blank?
			sqlwhere = sqlwhere + " and wk_shipments.parent_type = '#{parentType}'  "
		end

		if !@from.blank? && !@to.blank?
			sqlwhere = sqlwhere + " and wk_shipments.shipment_date between '#{@from}' and '#{@to}'  "
		end

		if delivery_status.present?
			delivery = delivery.joins(:wkstatus).joins("INNER JOIN (
				SELECT status_for_id, MAX(status_date) AS status_date
				FROM wk_statuses WHERE status_for_type='WkShipment' #{get_comp_condition('wk_statuses')}
				GROUP BY status_for_id
			) AS CS ON CS.status_for_id = wk_statuses.status_for_id AND CS.status_date = wk_statuses.status_date")
			sqlwhere = sqlwhere + " and wk_statuses.status = '#{delivery_status}'  "
		end
		projectId = nil if projectId.blank?
		shipmentIDs = projectId != 'AP' ? delivery.where(wk_delivery_items: {project_id: projectId}).pluck(:id) : []
		delivery = delivery.where(sqlwhere)
		delivery = delivery.where(" wk_shipments.id IN (?)", shipmentIDs) if shipmentIDs.length > 0
		delivery = delivery.reorder(sort_clause)
		respond_to do |format|
			format.html {
				formPagination(delivery)
				@totaldeliveryAmt = @deliveryEntries.sum("wk_delivery_items.total_quantity*wk_delivery_items.selling_price")
			}
			format.csv{
				headers = {serial_number: l(:label_serial_number), name: l(:field_name), shipment_date: l(:label_delivery_date), status: l(:field_status), amount: l(:field_amount)}
				data = delivery.map{|entry| {serial_number: entry.serial_number, name: entry&.parent&.name || '', shipment_date: entry.shipment_date, status: getDeliveryStatus[entry.current_status], amount: ((entry.delivery_items[0]&.currency.to_s || '') + ' ' + (entry&.delivery_items&.sum('wk_delivery_items.total_quantity*wk_delivery_items.selling_price').round(2).to_s || ''))} }
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "delivery.csv")
			}
		end
	end

	def edit
		@shipment = WkShipment.new
		@deliveryItem = Array.new
		@deliveryItem << @shipment.delivery_items.new(currency: Setting.plugin_redmine_wktime['wktime_currency']) if !params[:populate_items]
		if params[:populate_items]
			@shipment.parent_id = params[:related_parent].to_i
			@shipment.parent_type = params[:related_to]
			invoices = []
			material_entries = WkMaterialEntry.getMaterialInvoice(params[:delivery_invoice_id])
			if material_entries.present?
				@materialID = []
				@shipment.invoice_id = params[:delivery_invoice_id].to_i
				material_entries.each do |item|
					@materialID << item.id
					delivery = @shipment.delivery_items.new
					delivery.inventory_item_id = item.inventory_item_id
					delivery.location_id = item.location_id
					delivery.selling_price = item.selling_price
					delivery.currency = item.currency
					delivery.total_quantity = item.quantity
					delivery.serial_number = item.serial_no
					delivery.running_sn = item.running_sn
					delivery.notes = item.notes
					delivery.project_id = item.project_id
					@deliveryItem << delivery
				end
			else
				@deliveryItem << @shipment.delivery_items.new(currency: Setting.plugin_redmine_wktime['wktime_currency'])
			end
		end
		unless params[:delivery_id].blank?
			@shipment = WkShipment.find(params[:delivery_id].to_i)
			@deliveryItem = @shipment.delivery_items
		end
	end

	def update
		errorMsg = ""
		deliveryItem = nil
		if params["delivery_id"].present?
			@shipment = WkShipment.find(params["delivery_id"].to_i)
		else
			@shipment = WkShipment.new
			@shipment.shipment_type = getShipmentType
			@shipment.parent_id = params[:related_parent].to_i
			@shipment.parent_type = params[:related_to]
			@shipment.invoice_id = params[:delivery_invoice_id]
		end
		@shipment.serial_number = params[:serial_number]
		@shipment.shipment_date = params[:delivery_date]
		if @shipment&.wkstatus&.last&.status != 'D'
			saveStatus = false
			if params[:status] == 'L'
				saveStatus = true if @shipment&.wkstatus.blank?
			elsif params[:status] == 'D'
				saveStatus = true  if  @shipment&.wkstatus&.last&.status != params[:status]
			else
				saveStatus = true
			end
			wkstatus = [{status_for_type: "WkShipment", status: params[:status], status_date: Time.now, status_by_id: User.current.id, latitude: params[:latitude], longitude: params[:longitude]}]
			@shipment.wkstatus_attributes = wkstatus if saveStatus
		end
		unless @shipment.save()
			errorMsg = @shipment.errors.full_messages.join("\n")
		end
		totalRow = params[:totalrow].to_i
		i = 1
		sysCurrency = Setting.plugin_redmine_wktime['wktime_currency']
		while i <= totalRow
			if params["item_id_#{i}"].blank?
				deliveryItem = @shipment.delivery_items.new
				deliveryItem.inventory_item_id = params["product_item_id_#{i}"].to_i
				if sysCurrency != params["currency_#{i}"]
					deliveryItem.org_currency = params["currency_#{i}"]
					deliveryItem.org_selling_price = params["selling_price_#{i}"]
				end
				deliveryItem.currency = sysCurrency
				deliveryItem.selling_price = getExchangedAmount(params["currency_#{i}"], params["selling_price_#{i}"])
				deliveryItem.serial_number = params["serial_number_#{i}"]
				deliveryItem.running_sn = params["running_sn_#{i}"]
				deliveryItem.notes = params["notes_#{i}"]
				deliveryItem.total_quantity = params["total_quantity_#{i}"]
				deliveryItem.location_id = params["location_id_#{i}"].to_i if !params["location_id_#{i}"].blank? && params["location_id_#{i}"] != "0"
				deliveryItem.project_id = params["project_id_#{i}"]
				deliveryItem.save()
				errorMsg += deliveryItem.errors.full_messages.join("<br>")
				if errorMsg.blank? && params["material_id"].blank?
					inventoryItem = WkInventoryItem.find(deliveryItem.inventory_item_id.to_i)
					availQuantity = inventoryItem.available_quantity - params["total_quantity_#{i}"].to_i
					inventoryItem.available_quantity = availQuantity
					inventoryItem.save
				end
			end
			i = i + 1
		end
		if errorMsg.blank?
			redirect_to action: 'index', controller: controller_name, tab: controller_name
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
			redirect_to action: 'edit', delivery_id: @shipment.id
		end
	end

	def destroy
		delivery = WkShipment.find(params[:delivery_id].to_i)
		if delivery.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = delivery.errors.full_messages.join("<br>")
		end
		redirect_back_or_default action: 'index', tab: params[:tab]
	end

	def set_filter_session
		filters = [:period_type, :period, :contact_id, :account_id, :project_id, :polymorphic_filter, :from, :to, :delivery_status]
		super(filters, {from: @from, to: @to})
	end

	def formPagination(entries)
		@entry_count = entries.count
    setLimitAndOffset()
		@deliveryEntries = entries.limit(@limit).offset(@offset)
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

	def additionalContactType
		false
	end

	def additionalAccountType
		false
	end

	def getOrderAccountType
		'A'
	end

	def getOrderContactType
		'C'
	end

	def getAccountDDLbl
		l(:field_account)
	end

	def getShipmentType
		'O'
	end

	def showProjectDD
		true
	end

	def getAdditionalDD
		"wkdelivery/deliveryadditionaldd"
	end

	def textfield_size
		6
	end

	def load_product_items
		itemArr = ""
		if params[:update_DD] =='inventory_item'
			item = WkInventoryItem.getProductDetails(params[:id].to_i)&.first
			itemArr << item.id.to_s() + ',' + item.available_quantity.to_s() + ',' + item.cost_price.to_s() + ',' + item.selling_price.to_s() + ',' + item.over_head_price.to_s() + ',' + item.currency.to_s() + ',' + item.serial_number.to_s() + ',' + item.running_sn.to_s() + ',' + item.uom_id.to_s()  + ',' + "" unless item.blank?
		else
			WkInventoryItem.getProductItem(params[:product_id].to_i, params[:location_id].to_i).each do |item|
				name = item.product_item.brand.name + '-' + item.product_item.product_model.name + '-' + (item.currency.to_s() + ' ' +  item.selling_price.to_s()) +' - '+ (item.serial_number.to_s() + item.running_sn.to_s())
				itemArr << item.id.to_s() + ',' +  name + "\n"
			end
		end
		respond_to do |format|
			format.text  { render plain: itemArr }
		end
	end

	def delivery_slip
    edit
    render action: "delivery_slip", layout: false
	end

	def getSupplierAddress(invoice)
		getMainLocation + "\n" +  getAddress
	end

	def getCustomerAddress(invoice)
		invoice.parent.name + "\n" + (invoice.parent.address.blank? ? "" : invoice.parent.address.fullAddress)
	end

	def get_invoice_no
		invoiceArr = ""
		invoices = WkInvoice.get_invoice_numbers(params[:parent_type], params[:parent_id], 'I')
		invoiceArr << "" + ',' +  "" + "\n"
		invoices.each{|item| invoiceArr << item.id.to_s() + ',' +  item.invoice_number.to_s() + "\n" } if invoices.present?
		respond_to do |format|
			format.text  { render :plain => invoiceArr }
		end
	end
end
