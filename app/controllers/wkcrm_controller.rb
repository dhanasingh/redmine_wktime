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

class WkcrmController < WkbaseController

  before_action :require_login
  before_action :check_perm_and_redirect, :only => [:index, :edit, :update]
  before_action :check_crm_admin_and_redirect, :only => [:destroy]
  include WkcrmHelper
  include WktimeHelper
  accept_api_auth :get_act_related_ids, :get_crm_users

	def index
	end

	def get_act_related_ids
		relatedArr = params[:format] == "json" ? [] : ""
		relatedId = nil

		if params[:related_type] == "WkOpportunity"
			relatedId = WkOpportunity.all.order(:name)
		elsif params[:related_type] == "WkLead"
			relatedId = WkLead.includes(:contact).where.not(:status => 'C').where('wk_crm_contacts.contact_type' => 'C').order("wk_crm_contacts.first_name, wk_crm_contacts.last_name")
		elsif params[:related_type] == "WkCrmContact"
			#relatedId = WkCrmContact.includes(:lead).where(wk_leads: { status: ['C', nil] }).where(:contact_type => params[:contact_type]).order(:first_name, :last_name)
			hookType = call_hook(:additional_type)
			if hookType[0].blank? || params[:additionalContactType] == "false"
				relatedId = WkCrmContact.includes(:lead).where(:account_id => nil, :contact_id => nil).where(wk_leads: { status: ['C', nil] }).where(:contact_type => params[:contact_type]).order(:first_name, :last_name)
			else
				relatedId = WkCrmContact.includes(:lead).where(:account_id => nil, :contact_id => nil).where(wk_leads: { status: ['C', nil] }).where("wk_crm_contacts.contact_type = '#{params[:contact_type]}' or wk_crm_contacts.contact_type = '#{hookType[0]}'").order(:first_name, :last_name)
			end
		elsif params[:related_type] != "0"
			hookType = call_hook(:additional_type)
			if hookType[0].blank? || params[:additionalAccountType] == "false"
				relatedId = WkAccount.where(:account_type => params[:account_type]).order(:name)
			else
				relatedId = WkAccount.where("wk_accounts.account_type = '#{params[:account_type]}' or wk_accounts.account_type = '#{hookType[0]}'").order(:name)
			end
		end

		respond_to do |format|
			format.text  {
				(relatedId || []).each{ |entry| relatedArr << entry.id.to_s() + ',' + (params[:related_type] == "WkLead" ? entry.contact.name : entry.name) + "\n" }
				render :plain => relatedArr
			}
			format.json {
				(relatedId || []).each{ |entry| relatedArr << { value: entry.id, label: (params[:related_type] == "WkLead" ? entry.contact.name : entry.name) }}
				render :json => relatedArr
			}
		end
	end

	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end

	def check_crm_admin_and_redirect
	  unless validateERPPermission("A_CRM_PRVLG")
	    render_403
	    return false
	  end
	end

	def check_permission
		return validateERPPermission("B_CRM_PRVLG") || validateERPPermission("A_CRM_PRVLG")
	end

	def getContactController
		'wkcrmcontact'
	end

	def getAccountType
		'A'
	end

	def getContactType
		'C'
	end

	def deletePermission
		validateERPPermission("A_CRM_PRVLG")
	end

	def additionalContactType
		true
	end

	def get_crm_users
		render json: get_crm_Users
	end

	def additionalAccountType
		true
	end

	def accountSave
		errorMsg = nil
		if api_request?
			(params[:address] || []).each{|addr| params[addr.first] = addr.last }
			params.delete("address")
		end
		if params[:account_id].blank? || params[:account_id].to_i == 0
			wkaccount = WkAccount.new
		else
		  wkaccount = WkAccount.find(params[:account_id].to_i)
		end
		wkaccount.name = params[:account_name]
		wkaccount.account_type = getAccountType
		wkaccount.account_number = params[:account_number]
		wkaccount.assigned_user_id = params[:assigned_user_id]
		wkaccount.account_category = params[:account_category]
		wkaccount.description = params[:description]
		wkaccount.tax_number = params[:tax_number]
		wkaccount.account_billing = params[:account_billing].blank? ? 0 : params[:account_billing]
		wkaccount.location_id = params[:location_id] if params[:location_id] != "0"
		wkaccount.created_by_user_id = User.current.id if wkaccount.new_record?
		wkaccount.updated_by_user_id = User.current.id

		if wkaccount.valid?
			addrId = updateAddress
			wkaccount.address_id = addrId if addrId.present?
			wkaccount.save
		end
		wkaccount
	end

	def contactSave
		errorMsg = nil
		if api_request?
			(params[:address] || []).each{|addr| params[addr.first] = addr.last }
			params.delete("address")
		end
		if params[:contact_id].blank?
			wkContact = WkCrmContact.new
		else
			wkContact = WkCrmContact.find(params[:contact_id].to_i)
		end
		# For Contact table
		wkContact.assigned_user_id = params[:assigned_user_id]
		wkContact.first_name = params[:first_name]
		wkContact.last_name = params[:last_name]
		wkContact.address_id = params[:address_id]
		wkContact.title = params[:contact_title]
		wkContact.description = params[:description]
		wkContact.department = params[:department]
		wkContact.salutation = params[:salutation]
		wkContact.account_id = nil #params[:account_id]
		wkContact.contact_id = nil
		wkContact.account_id = params[:related_parent] if params[:related_to] == "WkAccount"
		wkContact.contact_id = params[:related_parent] if params[:related_to] == "WkCrmContact"
		wkContact.relationship_id = params[:relationship_id]
		wkContact.location_id = params[:location_id] if params[:location_id] != "0"
		wkContact.contact_type = getContactType
		wkContact.created_by_user_id = User.current.id if wkContact.new_record?
		wkContact.updated_by_user_id = User.current.id
		if wkContact.valid?
			addrId = updateAddress
			wkContact.address_id = addrId unless addrId.blank?
			wkContact.save
		end
		wkContact
	end

	def convert
		notice    = l(:notice_successful_convert)
		error_msg = nil
		redirect_params = { action: 'edit' }
		target = nil
		target_id = nil

		WkLead.transaction do
			error_msg = leadConvert(params)
			redirect_params = { account_id: @account&.id, contact_id: @contact&.id, lead_id: @lead&.id }
				if @hookType.present? && @hookType[0].present? && @hookType[0][3].present?
					redirect_params[@hookType[0][3]] = @hookType[0][2]
				end

			if @account.present?
				target = @hookType.blank? ? 'wkcrmaccount' : @hookType[0][1]
				target_id = @account.id
			else
				target = @hookType.blank? ? 'wkcrmcontact' : @hookType[0][1]
				target = 'wklead' if error_msg.present?
				target = 'wkreferrals' if @contact&.contact_type == 'IC'
				target_id = @lead&.id
			end
			if error_msg.blank?
				res = post_conversion
				if res.present?
					target = res[:target] 
					target_id = res[:target_id]
					redirect_params[:action] = res[:action]
				end
			else
				raise ActiveRecord::Rollback
			end
		end

		if error_msg.present?
			flash[:error] = error_msg
		elsif notice.present?
			flash[:notice] = notice
		end

		redirect_to redirect_params.merge(controller: target, id: target_id, tab: target)
	end

	def leadConvert(params)
		@lead = nil
		errorMsg = ""
		@lead = WkLead.find(params[:lead_id]) unless params[:lead_id].blank?
		@lead.status = 'C'
		@lead.updated_by_user_id = User.current.id
		@contact = @lead.contact
		if @contact.contact_type == "IC"
			unless @lead.save
				errorMsg += @lead.errors.full_messages.join("<br>")
			end
			convertToContact
		else
			@account = @lead.account
			@hookType = call_hook(:controller_convert_contact, {params: params, leadObj: @lead, contactObj: @contact, accountObj: @account})
			unless @account.blank?
				@account.account_type = @hookType.blank? ? getAccountType : @hookType[0][0]
			else
				@contact.contact_type = @hookType.blank? ? getContactType : @hookType[0][0]
			end
			unless @lead.save
				errorMsg += @lead.errors.full_messages.join("<br>")
			end
			errorMsg += convertToAccount unless @account.blank?
			errorMsg += convertToContact
		end
		errorMsg
	end

	def convertToAccount
		@account.updated_by_user_id = User.current.id
		address = nil
		unless @contact.address.blank?
			address = copyAddress(@contact.address)
			@account.address_id = address.id
		end
		@account.save ? "" : @account.errors.full_messages.join("<br>")
	end

	def convertToContact
		@contact.updated_by_user_id = User.current.id
		unless @account.blank?
			@contact.account_id = @account.id
		end
		@contact.save ? "" : @contact.errors.full_messages.join("<br>")
	end

	def copyAddress(source)
		target = WkAddress.new
		target = source.dup
		target.save
		target
	end

	def post_conversion
	end

	def is_referral
		false
	end

  def edit_label
    l(:label_lead)
  end

	def get_plural_activity_label
		l(:label_activity_plural)
	end

	def get_activity_label
		l(:label_new_activity)
	end

	def getLabelInvNum
		l(:label_quote_number)
	end

	def getDateLbl
		l(:label_quote_date)
	end

	def isInvPaymentLink
		false
	end
end
