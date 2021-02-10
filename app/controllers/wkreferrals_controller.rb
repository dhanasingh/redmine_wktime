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

class WkreferralsController < WkleadController
	unloadable
  before_action :require_login
  before_action :check_perm_and_redirect, only: [:update, :destroy]
	menu_item :wkattendance
  include WkleadHelper

  def index
    sort_init "updated_at", "desc"
		sort_update 'lead_name' => "CONCAT(C.first_name, C.last_name)",
			'status' => "#{WkLead.table_name}.status",
			'location_name' => "L.name",
			'acc_name' => "A.name",
			'updated_at' => "#{WkLead.table_name}.updated_at",
      "pass_out" => "wk_candidates.pass_out"

    entries = WkLead.referrals.reorder(sort_clause)
    @entries = formPagination(entries)
  end

  def destroy
    if @referral.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = @referral.errors.full_messages.join("<br>")
    end
    redirect_to action: "index", tab: "wkreferrals"
  end

  def deletePermission
    true
  end

  def edit_label
    l(:label_referral)
  end

  def is_referral
    true
  end

  private

  def check_perm_and_redirect
    @referral = WkLead.joins(:contact).where(id: params[:lead_id], "wk_crm_contacts.contact_type": "RF").first if params[:lead_id].present?
    render_404 if @referral&.id.blank? && params[:lead_id].present?
  end

	def formPagination(entries)
		@entry_count = entries.count
		setLimitAndOffset()
		entries.limit(@limit).offset(@offset)
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
