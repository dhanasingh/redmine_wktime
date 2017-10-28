class WkassetController < WkproductitemController
  unloadable
	include WktimeHelper


	# def index
	# end

	def getItemType
		'A'
	end
	
	def showAssetProperties
		true
	end
	
	def getProductAsset
		assetArr = ""
		unless params[:id].blank?
			pctObj = WkInventoryItem.joins(:product_item, :asset_property).where(:wk_product_items => {:product_id => params[:id].to_i}, :product_type => 'A').select("wk_inventory_items.id, wk_asset_properties.name")
		else 
			pctObj = WkInventoryItem.joins(:product_item, :asset_property).where(:product_type => 'A').select("wk_inventory_items.id, wk_asset_properties.name")
		end
		
		pctObj.each do | entry |
			assetArr << entry.id.to_s() + ',' +  entry.name.to_s()  + "\n" 
		end
		respond_to do |format|
			format.text  { render :text => assetArr }
		end
	end

end
