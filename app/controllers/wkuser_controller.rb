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

class WkuserController < WkbaseController
  
  menu_item :wkattendance
  include WkpayrollHelper
	include WktimeHelper

	before_action :require_login
  before_action :check_perm_and_redirect, :only => [:edit, :save]

  def index
		if validateERPPermission('A_EMP')
      sort_init "updated_at", "desc"
      sort_update "user_name" => "CONCAT(users.firstname, users.lastname)",
                "email" => "email_addresses.address"
      set_filter_session
      getUsersAndGroups
      @status = getSession(:status) == "0" ? nil : getSession(:status) || 1

      entries = User.joins(:email_address).reorder(sort_clause)
      if @status.present?
        entries = entries.where("users.status = ? ", @status)
      end
      if getSession(:group_id).present?
        entries = entries.in_group(getSession(:group_id))
      end
      if getSession(:name).present?
        entries = entries.where("LOWER(users.firstname) like LOWER('%#{getSession(:name)}%') or LOWER(users.lastname) like LOWER('%#{getSession(:name)}%') or LOWER(users.login) like LOWER('%#{getSession(:name)}%')")
      end

      respond_to do |format|
        format.html do
          @user_count = entries.length
          @user_pages = Paginator.new @user_count, per_page_option, params["page"]
          @userEntries = entries.limit(@user_pages.per_page).offset(@user_pages.offset).to_a
          render :layout => !request.xhr?
        end
        format.api
        format.csv do
          headers = {user: l(:field_user), email: l(:field_mail), role: l(:field_role), joindate: l(:field_join_date) }
          data = entries.map{|e| {user: e.name, email: e.mail, role: e&.erpmineuser&.role, joindate: e&.erpmineuser&.join_date }}
          send_data(csv_export(headers: headers, data: data), type: "text/csv; header=present", filename: "employee.csv")
        end
      end
    else
      redirect_to action: "profile", tab: "wkuser"
    end
  end

  def edit
    if params[:id].present?
      @user = WkUser.where("id =?", params[:id]).first
    end
  end

  def profile
    @user = WkUser.where("user_id =?", User.current.id).first
  end

  def save
    wkUser = WkUser.find(params[:erpmineuser][:id])
    user_id = params[:erpmineuser][:user_id]
    params[:erpmineuser][:address_id] = updateAddress
    wkUser.assign_attributes(wkUser_params(params[:erpmineuser]))
    errorMsg = ""
    if wkUser.save
      if params[:attachment_ids].present?
        attachments = Attachment.where(id: params[:attachment_ids].split(","))
        attachments.each do |a|
          a = a.attributes
          a.merge!({id: nil, container_id: user_id, container_type: "Principal"})
          attach = Attachment.new(a)
          errorMsg += attach.errors.full_messages.to_s unless attach.save
        end
      end
      # for attachment save
      errorMsg += save_attachments(user_id, params[:attachments], params[:container_type]) if params[:attachments].present?
    else
      errorMsg = wkUser.errors.full_messages.join("<br>")
    end
    if errorMsg.blank?
      flash[:notice] = l(:notice_successful_update)
      redirect_to action: "index", tab: "wkuser"
    else
      flash[:error] = errorMsg
      redirect_to action: "edit", tab: "wkuser"
    end
  end

  def wkUser_params(wkParams)
    wkParams.permit(:user_id, :role_id, :id1, :id2, :id3, :join_date, :birth_date, :termination_date, :gender, :bank_name, :account_number, :bank_code, :loan_acc_number, :tax_id, :ss_id, :custom_number1, :custom_number2, :custom_date1, :custom_date2, :is_schedulable, :billing_rate, :billing_currency, :location_id, :department_id, :address_id, :shift_id, :created_by_user_id, :updated_by_user_id, :source_id, :source_type, :retirement_account, :marital_id, :state_insurance,:employee_id, :emerg_type_id, :emergency_contact, :dept_section_id, :notes)
  end

	def set_filter_session
		@filters = [:group_id, :name, :status]
		super(@filters)
  end

  def get_filter(key)
    return session[controller_name] && session[controller_name][key]
  end

	def check_perm_and_redirect
		unless validateERPPermission('A_EMP')
			render_403
			return false
		end
	end
end
