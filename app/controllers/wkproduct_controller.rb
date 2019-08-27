class WkproductController < WkinventoryController
  unloadable
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy, :category, :updateCategory]


	def index
		sort_init 'id', 'asc'
		sort_update 'product_name' => "name",
					'category' => "category_id",
					'uom' => "uom_id"

		set_filter_session
		categoryId = session[controller_name].try(:[], :category_id)
		name = session[controller_name].try(:[], :name)
		@productEntries = nil
		sqlStr = ""
		unless name.blank?
			sqlStr = "LOWER(name) like LOWER('%#{name}%')"
		end
		unless categoryId.blank?
			sqlStr = sqlStr + " AND" unless sqlStr.blank?
			sqlStr = sqlStr + " category_id = #{categoryId}"
		end
		unless sqlStr.blank?
			entries = WkProduct.where(sqlStr)
		else
			entries = WkProduct.all
		end
		formPagination(entries.reorder(sort_clause))
    end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@productEntries = entries.order(:name).limit(@limit).offset(@offset)
	end
	
	def edit
	    @productEntry = nil
	    unless params[:product_id].blank?
		   @productEntry = WkProduct.find(params[:product_id])
		   @applicableTaxes = @productEntry.taxes.map { |r| r.id }
		end 
	end	
    
	def update	
		if params[:product_id].blank?
		  product = WkProduct.new
		else
		  product = WkProduct.find(params[:product_id])
		end
		product.name = params[:name]
		product.product_type = params[:product_type].blank? ? nil : params[:product_type]
		product.category_id = params[:category_id]
		product.uom_id = params[:uom_id]
		product.attribute_group_id = params[:attribute_group_id]
		product.description = params[:description]
		product.depreciation_rate = params[:depreciation_rate].to_f/100.00
		product.ledger_id = params[:ledger_id]
		if product.save()
			unless product.id.blank?
				taxId = params[:tax_id]	
				WkProductTax.where(:product_id => product.id).where.not(:tax_id => taxId).delete_all()
				unless taxId.blank?
					taxId.collect{ |id| 
						istaxid = WkProductTax.where("product_id = ? and tax_id = ? ", product.id, id).count
						unless istaxid > 0
							productTax = WkProductTax.new
							productTax.product_id = product.id
							productTax.tax_id = id
							if !productTax.save()
								errorMsg = productTax.errors.full_messages.join("<br>")
							end
						end						
					}
				end
			end
		    redirect_to :controller => 'wkproduct',:action => 'index' , :tab => 'wkproduct'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkproduct',:action => 'edit' , :product_id => params[:product_id], :tab => 'wkproduct'
		    flash[:error] = product.errors.full_messages.join("<br>")
		end
    end
	
	def destroy
		product = WkProduct.find(params[:product_id].to_i)
		if product.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = product.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end

	def category
		entries = WkProductCategory.all	
		formPagination(entries)
	end

	def updateCategory
		arrId = WkProductCategory.all.pluck(:id)
		for i in 0..params[:category_id].length-1
			if params[:category_id][i].blank?
				category = WkProductCategory.new
			else
				category = WkProductCategory.find(params[:category_id][i].to_i)
				arrId.delete(params[:category_id][i].to_i)
			end
			category.name = params[:name][i]
			category.description = params[:description][i]
			category.save()			
		end
		
		if !arrId.blank?			
			WkProductCategory.where(:id => arrId).destroy_all
		end
		
		redirect_to :controller => 'wkproduct',:action => 'category' , :tab => 'wkproduct'
		flash[:notice] = l(:notice_successful_update)
	end  

	def set_filter_session
		if params[:searchlist] == controller_name
			session[controller_name] = Hash.new if session[controller_name].nil?
			filters = [:category_id, :name]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
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