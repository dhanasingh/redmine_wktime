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

class WkattributegroupController < WkinventoryController

   menu_item :wkproduct
   before_action :require_login
   before_action :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy, :edit_product_attribute, :update_product_attribute]
   before_action :check_admin_redirect, :only => [:destroy, :destroy_product_attribute]


    def index
		sort_init 'name', 'asc'
		sort_update 'name' => "name",
					'description' => "description"

		set_filter_session
		name = getSession(:name)
		@groupEntries = nil
		sqlStr = ""
		unless name.blank?
			sqlStr = "LOWER(name) like LOWER('%#{name}%')"
		end
		unless sqlStr.blank?
			entries = WkAttributeGroup.where(sqlStr)
		else
			entries = WkAttributeGroup.all
		end
		entries = entries.reorder(sort_clause)
		respond_to do |format|
			format.html {
				@groupEntries = formPagination(entries)
			}
			format.csv{
				headers = {name: l(:field_name), description: l(:field_description)}
				data = entries.collect{|entry| {name: entry.name, type: entry.description} }
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "attributegroup.csv")
			}
		end
    end

	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		pageEntries = entries.limit(@limit).offset(@offset)
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

	def update_product_attribute
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

	def destroy_product_attribute
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

	def set_filter_session
		filters = [:name]
		super(filters)
	end

end
