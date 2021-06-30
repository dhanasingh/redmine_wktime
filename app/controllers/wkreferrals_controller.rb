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
  before_action :require_login, :check_module_permission
  before_action :check_perm_and_redirect, only: [:update, :destroy]
  before_action :check_permission, only: :getEmpDetails
	menu_item :wkattendance

  def index
    sort_init "updated_at", "desc"
		sort_update "lead_name" => "CONCAT(C.first_name, C.last_name)",
			"status" => "#{WkLead.table_name}.status",
			"location_name" => "L.name",
			"updated_at" => "#{WkLead.table_name}.updated_at",
      "pass_out" => "wk_candidates.pass_out",
      "referred_by" => "referred_by"

    set_filter_session
    entries = WkLead.referrals(deletePermission)
    entries = entries.filter_name(get_filter(:lead_name)) if get_filter(:lead_name)
    entries = entries.filter_status(get_filter(:status)) if get_filter(:status)
    entries = entries.filter_location(get_filter(:location_id)) if get_filter(:location_id) && get_filter(:location_id) != "0"
    entries = entries.reorder(sort_clause)

		respond_to do |format|
			format.html do
        @entries = formPagination(entries)
			  render :layout => !request.xhr?
      end
			format.api do
        @entries = entries
      end
      format.csv do
        headers = {name: l(:field_name), status: l(:field_status), location: l(:label_location), workphone: l(:label_work_phone), email: l(:field_mail),
          degree: l(:label_degree), passout: l(:label_pass_out), referredby: l(:label_referred_by), modifiedby: l(:field_status_modified_by)
        }
        data = entries.map do |e|
          { name: e.contact&.name, status: getLeadStatusHash[e.status], location: e.contact&.location&.name, workphone: e.contact&.address&.work_phone,
            email: e.contact&.address&.email, degree: e.candidate&.degree, passout: e.candidate&.pass_out, referredby: e.referred&.name,
            modifiedby: e.created_by_user&.name
          }
        end
        send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "referrals.csv")
      end
		end
  end

  def destroy
    if @referral.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = @referral.errors.full_messages.join("<br>") + @referral.contact.errors.full_messages.join("<br>")
    end
    redirect_to action: "index", tab: "wkreferrals"
  end

	def getEmpDetails
    referral = WkLead.referrals(true, params[:id]).first
    attachment_ids = referral.attachments.pluck(:id) if referral.attachments.any?
    data = {
      contact: referral&.contact, address: referral&.contact&.address, attachment_ids: (attachment_ids || []),
      source_id: referral&.contact&.id, source_type: referral&.contact&.class&.name
    }
    render json: data
	end

  def deletePermission
    validateERPPermission("A_REFERRAL")
  end

  def edit_label
    l(:label_referral)
  end

  def is_referral
    true
  end

	def get_plural_activity_label
		l(:label_interviews)
	end

	def get_activity_label
		l(:label_interview)
	end

  private

  def check_perm_and_redirect
    @referral = WkLead.joins(:contact).where(id: params[:lead_id], "wk_crm_contacts.contact_type": "IC").first if params[:lead_id].present?
    render_404 if @referral&.id.blank? && params[:lead_id].present?
  end

	def formPagination(entries)
		@entry_count = entries.count
		setLimitAndOffset()
		entries.limit(@limit).offset(@offset)
	end

  def check_module_permission
    render_404 unless isChecked("wktime_enable_referrals_module")
  end

  def check_permission
    render_404 if params[:id].blank?
  end

	def set_filter_session
		filters = [:lead_name, :status, :location_id]
		super(filters, {location_id: WkLocation.default_id, status: "N" })
	end

  def get_filter(key)
    return session[controller_name] && session[controller_name][key]
  end
end
