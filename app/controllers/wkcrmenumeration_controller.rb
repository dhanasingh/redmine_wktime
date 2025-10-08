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

class WkcrmenumerationController < WkbaseController

  include WktimeHelper
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy]

  accept_api_auth :get_crm_enumerations
  include WkcrmenumerationHelper

    def index
		sort_init 'type', 'asc'
		sort_update 'type' => "enum_type",
					'name' => "name",
					'position' => "position"

		set_filter_session
		enumName = session[controller_name].try(:[], :enumname)
		enumerationType =  session[controller_name].try(:[], :enumType)
		entries = nil
		if !enumName.blank? &&  !enumerationType.blank?
			entries = WkCrmEnumeration.where(:enum_type => enumerationType).where("LOWER(name) like LOWER(?)", "%#{enumName}%")
		elsif enumName.blank? &&  !enumerationType.blank?
			entries = WkCrmEnumeration.where(:enum_type => enumerationType)
		elsif !enumName.blank? &&  enumerationType.blank?
			entries = WkCrmEnumeration.where("LOWER(name) like LOWER(?)", "%#{enumName}%")
		else
			entries = WkCrmEnumeration.all
		end
		entries = entries.reorder(sort_clause)
		respond_to do |format|
			format.html {
				formPagination(entries)
			}
			format.csv{
				headers = {type: l(:field_type), name: l(:field_name), position: l(:label_position), active: l(:field_active), default: l(:field_is_default) }
				data = entries.map{|entry| {type: enumType[entry&.enum_type], name: entry.name, position: entry.position,  active: entry.active, default: entry.is_default} }
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "enumeration.csv")
			}
		end
    end

	def edit
		@enumEntry = nil
		unless params[:enum_id].blank?
			@enumEntry = WkCrmEnumeration.find(params[:enum_id].to_i)
		end
	end

	def update
		wkcrmenumeration = nil
		unless params[:enum_id].blank?
			wkcrmenumeration = WkCrmEnumeration.find(params[:enum_id].to_i)
		else
			wkcrmenumeration = WkCrmEnumeration.new
		end
		wkcrmenumeration.name = params[:enumname]
		wkcrmenumeration.position = params[:enumPosition]
		wkcrmenumeration.active = params[:enumActive]
		wkcrmenumeration.enum_type = params[:enumType]
		wkcrmenumeration.is_default = params[:enumDefaultValue]
		if wkcrmenumeration.valid?
			wkcrmenumeration.save
			redirect_to :controller => 'wkcrmenumeration',:action => 'index' , :tab => 'wkcrmenumeration'
			flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = wkcrmenumeration.errors.full_messages.join("<br>")
			redirect_to :controller => 'wkcrmenumeration',:action => 'edit'
		end
	end

	def set_filter_session
		filters = [:enumname, :enumType]
		super(filters)
	end

	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@crmenum = entries.limit(@limit).offset(@offset)
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

	def destroy
		WkCrmEnumeration.find(params[:enum_id].to_i).destroy

		flash[:notice] = l(:notice_successful_delete)
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end

	def check_perm_and_redirect
		unless User.current.admin? || hasSettingPerm
			render_403
			return false
		end
	end

	def get_crm_enumerations
		if params[:enum_type]
			enums= getEnumerations(params[:enum_type])
			render json: enums
		else
			render_403
		end
	end
end
