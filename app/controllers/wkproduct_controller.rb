class WkproductController < WkinventoryController
  unloadable
  before_filter :require_login
  before_filter :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy, :category, :updateCategory]


  def index
		@productEntries = nil
		sqlStr = ""
		unless params[:name].blank?
			sqlStr = "LOWER(name) like LOWER('%#{params[:name]}%')"
		end
		unless params[:category_id].blank?
			sqlStr = sqlStr + " AND" unless sqlStr.blank?
			sqlStr = sqlStr + " category_id = #{params[:category_id]}"
		end
		unless sqlStr.blank?
			entries = WkProduct.where(sqlStr)
		else
			entries = WkProduct.all
		end
		formPagination(entries)
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
		product.product_type = params[:product_type]
		product.category_id = params[:category_id]
		product.uom_id = params[:uom_id]
		product.attribute_group_id = params[:attribute_group_id]
		product.description = params[:description]
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
			WkProductCategory.destroy_all(:id => arrId)
		end
		
		redirect_to :controller => 'wkproduct',:action => 'category' , :tab => 'wkproduct'
		flash[:notice] = l(:notice_successful_update)
	end
	
	# def edit_category
		# @categoryEntry = nil
	    # unless params[:category_id].blank?
		   # @categoryEntry = WkProductCategory.find(params[:category_id])
		# end 
	# end
	
	# def updateCategory
		# if params[:category_id].blank?
		  # category = WkProductCategory.new
		# else
		  # category = WkProductCategory.find(params[:category_id])
		# end
		# category.name = params[:name]
		# category.description = params[:description]
		# if category.save()
		    # redirect_to :controller => 'wkproduct',:action => 'edit_category' , :tab => 'wkproduct'
		    # flash[:notice] = l(:notice_successful_update)
		# else
		    # redirect_to :controller => 'wkproduct',:action => 'edit_category' , :tab => 'wkproduct'
		    # flash[:error] = product.errors.full_messages.join("<br>")
		# end
	# end
	
	# def destroyCategory
		# category = WkProductCategory.find(params[:category_id].to_i)
		# if category.destroy
			# flash[:notice] = l(:notice_successful_delete)
		# else
			# flash[:error] = category.errors.full_messages.join("<br>")
		# end
		# redirect_back_or_default :action => 'edit_category', :tab => params[:tab]
	# end
  
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
