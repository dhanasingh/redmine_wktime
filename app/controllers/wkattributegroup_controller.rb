class WkattributegroupController < WkinventoryController
   unloadable
   menu_item :wkproduct
   before_action :require_login
   before_action :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy, :edit_product_attribute, :updateProductAttribute]
   before_action :check_admin_redirect, :only => [:destroy, :destroyProductAttribute]


    def index
		sort_init 'id', 'asc'
		sort_update 'name' => "name",
					'description' => "description"
		@groupEntries = nil
		sqlStr = ""
		unless params[:name].blank?
			sqlStr = "LOWER(name) like LOWER('%#{params[:name]}%')"
		end
		unless sqlStr.blank?
			entries = WkAttributeGroup.where(sqlStr)
		else
			entries = WkAttributeGroup.all
		end
		@groupEntries = formPagination(entries.reorder(sort_clause))
    end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		pageEntries = entries.order(:name).limit(@limit).offset(@offset)
		pageEntries
	end
	
	def edit
	    @groupEntry = nil
	    unless params[:group_id].blank?
		   @groupEntry = WkAttributeGroup.find(params[:group_id])
		   @groupAttrEntries = formPagination(@groupEntry.product_attributes)
		end 
	end	
    
	def update	
		if params[:group_id].blank?
		  attrGroup = WkAttributeGroup.new
		else
		  attrGroup = WkAttributeGroup.find(params[:group_id])
		end
		attrGroup.name = params[:name]
		attrGroup.description = params[:description]
		if attrGroup.save()
		    redirect_to :controller => 'wkattributegroup',:action => 'index' , :tab => 'wkattributegroup'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkattributegroup',:action => 'index' , :tab => 'wkattributegroup'
		    flash[:error] = attrGroup.errors.full_messages.join("<br>")
		end
    end
	
	def destroy
		attrGroup = WkAttributeGroup.find(params[:group_id].to_i)
		if attrGroup.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = attrGroup.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
	
	def edit_product_attribute
		@attributeEntry = nil
		@groupEntry = WkAttributeGroup.find(params[:group_id].to_i)
	    unless params[:product_attribute_id].blank?
		   @attributeEntry = WkProductAttribute.find(params[:product_attribute_id])
		end 
	end
	
	def updateProductAttribute
		if params[:product_attribute_id].blank?
		  productAttr = WkProductAttribute.new
		else
		  productAttr = WkProductAttribute.find(params[:product_attribute_id])
		end
		productAttr.name = params[:name]
		productAttr.group_id = params[:group_id]
		productAttr.description = params[:description]
		if productAttr.save()
		    redirect_to :controller => 'wkattributegroup',:action => 'edit' , :tab => 'wkattributegroup', :group_id => productAttr.group_id
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkattributegroup',:action => 'edit' , :tab => 'wkattributegroup', :group_id => productAttr.group_id
		    flash[:error] = product.errors.full_messages.join("<br>")
		end
	end
	
	def destroyProductAttribute
		productAttr = WkProductAttribute.find(params[:product_attribute_id].to_i)
		groupId = productAttr.group_id
		if productAttr.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = productAttr.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'edit' , :tab => 'wkattributegroup', :group_id => groupId
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

end
