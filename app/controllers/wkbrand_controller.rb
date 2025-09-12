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

class WkbrandController < WkinventoryController

  menu_item :wkproduct
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy, :edit_product_model, :update_product_model]
  before_action :check_admin_redirect, :only => [:destroy, :destroy_product_model]


    def index
		sort_init 'name', 'asc'
		sort_update 'name' => "name",
					'description' => "description"

		set_filter_session
		name = getSession(:name)
		@brandEntries = nil
		sqlStr = ""
		unless name.blank?
			sqlStr = "LOWER(name) like LOWER('%#{name}%')"
		end
		unless sqlStr.blank?
			entries = WkBrand.where(sqlStr)
		else
			entries = WkBrand.all
		end
		entries = entries.reorder(sort_clause)
		respond_to do |format|
			format.html {
				@brandEntries = formPagination(entries)
			}
			format.csv{
				headers = {name: l(:field_name), description: l(:field_description)}
				data = entries.collect{|entry| {name: entry.name, type: entry.description} }
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "brand.csv")
			}
		end
    end

	def formPagination(entries,orderColumn = nil)
		@entry_count = entries.count
		setLimitAndOffset()
		pageEntries = entries.order(orderColumn).limit(@limit).offset(@offset)
		pageEntries
	end

	def edit
		@brandEntry = nil
		unless params[:brand_id].blank?
			@brandEntry = WkBrand.find(params[:brand_id])
			orderColumn = 'product_id, name'
			@productModelEntries = formPagination(@brandEntry.product_models, orderColumn)
			@brandProducts = @brandEntry.brand_products.map { |r| r.product_id }
		end
	end

	def update
		if params[:brand_id].blank?
		  brand = WkBrand.new
		else
		  brand = WkBrand.find(params[:brand_id])
		end
		brand.name = params[:name]
		brand.description = params[:description]
		if brand.save()
			unless brand.id.blank?
				productId = params[:product_id]
				WkBrandProduct.where(:brand_id => brand.id).where.not(:product_id => productId).delete_all()
				unless productId.blank?
					productId.collect{ |id|
						isproductid = WkBrandProduct.where("brand_id = ? and product_id = ? ", brand.id, id).count
						unless isproductid > 0
							brandProduct = WkBrandProduct.new
							brandProduct.brand_id = brand.id
							brandProduct.product_id = id
							if !brandProduct.save()
								errorMsg = brandProduct.errors.full_messages.join("<br>")
							end
						end
					}
				end
			end
		    redirect_to :controller => 'wkbrand',:action => 'index' , :tab => 'wkbrand'
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkbrand',:action => 'index' , :tab => 'wkbrand'
		    flash[:error] = brand.errors.full_messages.join("<br>")
		end
	end

	def destroy
		brand = WkBrand.find(params[:brand_id].to_i)
		if brand.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = brand.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end

	def edit_product_model
		@modelEntry = nil
		@brand = WkBrand.find(params[:brand_id].to_i)
		unless params[:product_model_id].blank?
			@modelEntry = WkProductModel.find(params[:product_model_id])
		end
	end

	def update_product_model
		if params[:product_model_id].blank?
		  productModel = WkProductModel.new
		else
		  productModel = WkProductModel.find(params[:product_model_id])
		end
		productModel.name = params[:name]
		productModel.description = params[:description]
		productModel.product_id = params[:product_id]
		productModel.brand_id = params[:brand_id]
		if productModel.save()
		    redirect_to :controller => 'wkbrand',:action => 'edit' , :tab => 'wkbrand', :brand_id => productModel.brand_id
		    flash[:notice] = l(:notice_successful_update)
		else
		    redirect_to :controller => 'wkbrand',:action => 'edit_product_model' , :tab => 'wkbrand', :brand_id => productModel.brand_id
		    flash[:error] = productModel.errors.full_messages.join("<br>")
		end
		if params[:automatic_product_item].present? && params[:product_model_id].blank?
			productItem = WkProductItem.new
			productItem.part_number = params[:mod_part_number]
			productItem.product_id = params[:product_id]
			productItem.brand_id = params[:brand_id]
			productItem.product_model_id = productModel.id
			productItem.save()
		end
	end

	def destroy_product_model
		productModel = WkProductModel.find(params[:product_model_id].to_i)
		brandId = productModel.brand_id
		if productModel.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = productModel.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'edit' , :tab => 'wkbrand', :brand_id => brandId
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

	def set_filter_session
		filters = [:name]
		super(filters)
	end

end
