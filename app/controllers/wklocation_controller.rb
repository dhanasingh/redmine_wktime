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

class WklocationController < WkbaseController

  MAX_FILTER_LEVELS = 2

  menu_item :wkcrmenumeration
  include WktimeHelper
  include WkdocumentHelper
  helper :wkdocument
  helper :attachments
  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy]
	accept_api_auth :getlocations

  	def index
		set_filter_session
		locationName = session[controller_name].try(:[], :location_name)
		locationType =  session[controller_name].try(:[], :location_type)
		entries = WkLocation.all

		if locationType.present? && locationType.to_i != 0
			entries = entries.where(:location_type_id => locationType.to_i)
		end

		if locationName.present?
			entries = entries.where("LOWER(wk_locations.name) like LOWER(?) ", "%#{locationName}%")
		end

		# Cascading location filter. Each level picks a specific location whose
		# children populate the next level's dropdown. Validate the chain: each
		# selected location must be a child of the previous one.
		validated_path = []
		prev_id = nil
		(1..MAX_FILTER_LEVELS).each do |n|
			val = session[controller_name].try(:[], :"location_level_#{n}")
			break if val.blank? || val.to_i == 0
			loc = WkLocation.find_by(id: val.to_i)
			break unless loc
			if validated_path.empty?
				break unless loc.parent_id.nil?
			else
				break unless loc.parent_id == prev_id
			end
			validated_path << loc
			prev_id = loc.id
		end

		# When a path is chosen, restrict the list to that location's subtree.
		if validated_path.any?
			current = validated_path.last
			subtree_ids = [current.id] + current.descendants.pluck(:id)
			entries = entries.where(id: subtree_ids)
		end

		# Build the cascading dropdowns. Level 1 = root names. Level N+1 shows
		# all children of the level-N selection, but the dropdown itself is
		# skipped if none of its options has children of its own (no further
		# drill-down possible).
		@level_selections = validated_path.map(&:id)
		@level_options = []
		@level_options << WkLocation.where(parent_id: nil).order(:name).pluck(:name, :id)
		validated_path.first(MAX_FILTER_LEVELS - 1).each do |loc|
			candidate_ids = WkLocation.where(parent_id: loc.id).order(:name).pluck(:id)
			break if candidate_ids.empty?
			break unless WkLocation.where(parent_id: candidate_ids).exists?
			@level_options << WkLocation.where(id: candidate_ids).order(:name).pluck(:name, :id)
		end

		entries = entries.includes(:address, :location_type)
		ordered_entries, @depths, @ancestor_ids = tree_ordered_by_name(entries)

		respond_to do |format|
			format.html {
				formPaginationFromArray(ordered_entries)
			}
			format.csv{
				headers = {name: l(:field_name), type: l(:field_type), address: l(:label_account_address1), city: l(:label_city), state: l(:label_state), default: l(:field_is_default), main: l(:label_main_location)}
				data = ordered_entries.collect{|entry| {name: entry.name, type: entry&.location_type&.name, address: entry&.address&.address1, city: entry&.address&.city, state: entry&.address&.state, default: entry.is_default, main: entry.is_main} }
				send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "location.csv")
			}
		end
  	end

	# DFS over the visible set with siblings sorted alphabetically.
	# Returns [ordered_array, depths_hash, ancestor_ids_hash].
	def tree_ordered_by_name(entries)
		all = entries.to_a
		visible_ids = all.index_by(&:id)
		children_of = all.group_by(&:parent_id)
		children_of.each_value { |arr| arr.sort_by! { |l| l.name.to_s.downcase } }

		ordered = []
		depths = {}
		ancestor_ids = {}

		walk = lambda do |node, stack|
			depths[node.id] = stack.size
			ancestor_ids[node.id] = stack.dup
			ordered << node
			(children_of[node.id] || []).each { |c| walk.call(c, stack + [node.id]) }
		end

		# Roots in the visible set = rows whose parent is not visible (true root, or
		# parent filtered out). Sort by name and walk each.
		roots = all.reject { |l| l.parent_id && visible_ids.key?(l.parent_id) }
		roots.sort_by! { |l| l.name.to_s.downcase }
		roots.each { |r| walk.call(r, []) }

		[ordered, depths, ancestor_ids]
	end

	def formPaginationFromArray(arr)
		@entry_count = arr.size
		setLimitAndOffset()
		@locationObj = arr[@offset, @limit] || []
	end

  	def edit
		@locEntry = nil
		unless params[:location_id].blank?
			@locEntry = WkLocation.find(params[:location_id])
		end
  	end

  	def update
		errorMsg = nil
		if params[:location_id].blank? || params[:location_id].to_i == 0
			locationObj = WkLocation.new
		else
		  locationObj = WkLocation.find(params[:location_id].to_i)
		end
		locationObj.name = params[:location_name]
		locationObj.location_type_id = params[:location_type]
		locationObj.is_default = params[:defaultValue]
		locationObj.is_main = params[:defaultMain]
		locationObj.attachment_id = params[:attachment_id].present? ? params[:attachment_id] : nil
		locationObj.parent_id = params[:parent_id].presence
		unless locationObj.valid?
			errorMsg = errorMsg.blank? ? locationObj.errors.full_messages.join("<br>") : locationObj.errors.full_messages.join("<br>") + "<br/>" + errorMsg
		end
		if errorMsg.blank?
			addrId = updateAddress
			locationObj.address_id = addrId if addrId.present?
			locationObj.save
			#for attachment save
			errorMsg = save_attachments(locationObj.id) if params[:attachments].present?
		end
		if errorMsg.blank?
		    redirect_to :controller => controller_name,:action => 'index' , :tab => controller_name
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
		    redirect_to :controller => controller_name,:action => 'edit', :location_id => locationObj.id
		end
  	end

  	def destroy
		location = WkLocation.find(params[:location_id].to_i)
		subtree_ids = [location.id] + location.descendants.pluck(:id)

		blocking_ids = (
			WkInventoryItem.where(location_id: subtree_ids).distinct.pluck(:location_id) +
			WkCrmContact.where(location_id: subtree_ids).distinct.pluck(:location_id) +
			WkAccount.where(location_id: subtree_ids).distinct.pluck(:location_id)
		).uniq

		if blocking_ids.any?
			names = WkLocation.where(id: blocking_ids).order(:name).pluck(:name).join(', ')
			flash[:error] = l(:error_location_destroy_blocked, names: names)
		elsif location.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = location.errors.full_messages.join("<br>")
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
  	end

	def set_filter_session
		filters = [:location_name, :location_type, :show_on_map]
		filters += (1..MAX_FILTER_LEVELS).map { |n| :"location_level_#{n}" }
		super(filters)
	end

	def check_perm_and_redirect
		unless User.current.admin? || hasSettingPerm
			render_403
			return false
		end
	end

	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@locationObj = entries.limit(@limit).offset(@offset)
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

	def getlocations
		render json: getAllLocations
	end

	def location_tree

		locations =
			WkLocation.includes(:children)
								.where(parent_id: nil)

		render json:
			build_location_tree(locations)

	end

	def build_location_tree(locations)

		locations.map do |location|

			{
				id: location.id,
				name: location.name,

				children:
					build_location_tree(
						location.children
					)
			}

		end

	end

	def hierarchy_children
    if params[:parent_id].blank?
      # Edge case: no parent_id → return root locations (L1)
      locations = WkLocation
                    .includes(:location_type)
                    .where(parent_id: nil)
                    .order(:name)
    else
      locations = WkLocation
                    .includes(:location_type)
                    .where(parent_id: params[:parent_id])
                    .order(:name)
    end
 
    render json: locations.map { |loc|
      {
        id:           loc.id,
        name:         loc.name,
        type:         loc.location_type&.name,
        has_children: loc.children.exists?
      }
    }
  end
end
