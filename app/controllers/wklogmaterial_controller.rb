class WklogmaterialController < TimelogController
  unloadable
  before_action :require_login
	accept_api_auth :loadSpentType, :index, :spent_log, :modifyProductDD, :create, :update 
  helper :queries
  include QueriesHelper

  def index
		super
		respond_to do |format|
			format.api {
				render(layout: "wklogmaterial/material_index") if params[:spent_type] == "M" || params[:spent_type] == "A"
			}
    end
  end 
  
  def modifyProductDD
		pctArr = ""	
		productDetail = []	
		productType = 'I'
		hookLogType = 'A'
		hookType = call_hook(:modify_product_log_type, :params => params)
		unless hookType[0].blank?
			hookLogType = hookType[0]
		end
		wklogmatterial_helper = Object.new.extend(WklogmaterialHelper)
		wkasset_helper = Object.new.extend(WkassetHelper)
		rateper = wkasset_helper.getRatePerHash(false)
		if params[:ptype] == "product"
			logType =  params[:log_type] == 'M' ? 'I' : params[:log_type]
			pctObj = WkProduct.where("product_type = ? or product_type is null", logType).order(:name)
		elsif params[:ptype] == "brand_id"
			pObj = WkProduct.find(params[:id].to_i)
			pctObj = pObj.brands.order(:name)
		elsif params[:ptype] == "product_item"
			productType = params[:log_type]
			location = params[:location_id]
			pctObj = wklogmatterial_helper.mergePItemInvItemQuery(params[:id], productType, location)			
		elsif params[:ptype] == "product_model_id"
			unless params[:id].blank? || params[:id].to_i < 1
				pObj = WkBrand.find(params[:id].to_i)
				pctObj = pObj.product_models.where(:product_id => params[:product_id].to_i).order(:name)
			else
				pctObj = []
			end
		elsif params[:ptype] == "product_attribute_id"
			pObj = WkProduct.find(params[:id].to_i)
			pctObj = pObj.product_attributes.order(:name)
		elsif params[:ptype] == "uom_id"
			pctObj = WkInventoryItem.find(params[:id].to_i)	unless params[:id].blank?		
		else
			productType = params[:log_type]
			if productType == 'A' || productType == hookLogType 			
				pctObj = WkAssetProperty.where(:inventory_item_id => params[:id].to_i) unless params[:id].blank?
			else
				pctObj = WkInventoryItem.find(params[:id].to_i) unless params[:id].blank?
			end
		end
		
		if params[:ptype] == "product_item"
			pctObj.each do | entry|
				product = {}
				if productType == 'A' || productType == hookLogType					
					product = {value: entry.id, label: entry.asset_name.to_s() + ' - ' + entry.rate.to_s() + ' - ' + rateper[entry.rate_per].to_s()}
				else
					attributeName = entry.product_attribute.blank? ? "" : entry.product_attribute.name					
					product = {value: entry.id, label: entry.brand_name.to_s() +' - '+ entry.product_model_name.to_s() +' - '+ entry.part_number.to_s() +' - '+ attributeName  +' - '+  (entry.currency.to_s() + ' ' +  entry.selling_price.to_s())}
				end
				productDetail << product				
			end
		elsif params[:ptype] == "inventory_item"
			if (productType == 'A' || productType == hookLogType) && !pctObj.blank?
				pctObj.each do | entry|
					product = {}
					unitLabel = '/ ' + rateper[entry.rate_per].to_s()
					product = {inventory_item_id: entry.inventory_item_id, available_quantity: entry.inventory_item.available_quantity,
						cost_price: entry.inventory_item.cost_price, currency: entry.inventory_item.currency, rate: entry.rate,
						unitLabel: unitLabel}
					productDetail << product
				end				
			else
				productDetail << {id: pctObj.id, available_quantity: pctObj.available_quantity, cost_price: pctObj.cost_price,
					currency: pctObj.currency, selling_price: pctObj.selling_price}	unless pctObj.blank?
			end
		elsif params[:ptype] == "product_attribute"
			productDetail << {id: pctObj.id, available_quantity: pctObj.available_quantity, cost_price: pctObj.cost_price,
				currency: pctObj.currency, selling_price: pctObj.selling_price}	unless pctObj.blank?
		elsif params[:ptype] == "uom_id"
				productDetail << {value: pctObj.uom_id, label: pctObj.uom.blank? ? "" : pctObj.uom.name}	unless pctObj.blank?		
		else
			pctObj.each do | entry|
				productDetail << {value: entry.id, label: entry.name}
			end
		end
		respond_to do |format|
			format.text {
				productDetail.each do |entry|
					pct = ""
					entry.each{|key, value| pct += value.to_s + ',' }
					pct.slice!(pct.length - 1)
					pctArr << pct + "\n"
				end
				render plain: pctArr
			}
			format.api { render json: productDetail }
		end
	end  

	def loadSpentType
		wklogtime_helper = Object.new.extend(WklogmaterialHelper)
		spentTypeHash = wklogtime_helper.getLogHash
		respond_to do |format|
			format.text  {
				spentTypes = ""
				spentTypeHash.each{|key, value| spentTypes << key.to_s() + ',' +  value.to_s()  + "\n" }
				render(json: spentTypes)
			}
			format.json  {
				spentTypes = []
				spentTypeHash.delete("RA")  # if resident management Plugin present
				spentTypeHash.delete("E") if !wklogtime_helper.isChecked('wktime_enable_expense_module')
				if !wklogtime_helper.isChecked('wktime_enable_inventory_module')
					spentTypeHash.delete("M")
					spentTypeHash.delete("A")
				end
				spentTypeHash.each{|key, label| spentTypes << { value: key, label: label }}
				render(json: spentTypes)
			}
		end
	end

  # Returns the TimeEntry scope for index and report actions
  def time_entry_scope(options={})
    @query.results_scope(options)
  end
end
