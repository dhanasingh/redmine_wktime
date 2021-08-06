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

module WkleadHelper
include WktimeHelper
include WkcrmHelper
include WkcrmactivityHelper
include WkinvoiceHelper
include WkcrmenumerationHelper

	def getLeadStatusArr
		{
			"N" => l(:label_new),
			"A" => l(:label_assigned),
			"IP" => l(:label_in_process),
			"C" => l(:label_converted),
			"RC" => l(:label_recycled),
			"D" => l(:label_dead)
		}
	end

	def getFormComponent(fieldName, fieldValue, compSize, isShow)
		unless isShow
			text_field_tag(fieldName, fieldValue, :size => compSize)
		else
			fieldValue
		end
	end

	def update_without_redirect

		if params[:account_id].blank? || params[:account_id].to_i == 0
			wkaccount = WkAccount.new
		else
		    wkaccount = WkAccount.find(params[:account_id].to_i)
		end
		# For Account table
		wkaccount.name = params[:account_name]
		wkaccount.account_number = params[:account_number]
		wkaccount.description = params[:description]
		wkaccount.location_id = params[:location_id] if params[:location_id] != "0"
		if params[:lead_id].blank? || params[:lead_id].to_i == 0
			wkLead = WkLead.new
			wkContact = WkCrmContact.new
		else
		  wkLead = WkLead.find(params[:lead_id].to_i)
			wkContact = wkLead.contact
		end
		# For Lead table
		wkLead.status = params[:status].blank? ? 'N' : params[:status]
		wkLead.opportunity_amount = params[:opportunity_amount]
		wkLead.lead_source_id = params[:lead_source_id]
		wkLead.referred_by = (!is_referral || validateERPPermission("A_REFERRAL")) ? params[:referred_by] : User.current.id
		wkLead.created_by_user_id = User.current.id if wkLead.new_record?
		wkLead.updated_by_user_id = User.current.id
		wkLead.candidate_attributes = candidate_params(params[:candidate_attributes]) if is_referral

		# For Contact table
		wkContact.assigned_user_id = params[:assigned_user_id]
		wkContact.first_name = params[:first_name]
		wkContact.last_name = params[:last_name]
		wkContact.title = params[:title]
		wkContact.description = params[:description]
		wkContact.department = params[:department]
		wkContact.salutation = params[:salutation]
		wkContact.location_id = params[:location_id] if params[:location_id] != "0"
		wkContact.created_by_user_id = User.current.id if wkContact.new_record?
		wkContact.updated_by_user_id = User.current.id
		wkContact.contact_type = "IC" if is_referral
		if wkContact.valid?
			addrId = updateAddress
			unless addrId.blank?
				wkContact.address_id = addrId
				wkaccount.address_id = addrId
			end

			if wkaccount.valid?
				wkaccount.account_type = 'L'
				wkaccount.save
				wkLead.account_id = wkaccount.id
				wkContact.account_id = wkaccount.id
			end

			if wkContact.save
				wkLead.contact_id = wkContact.id
			end
			@isConvert = wkLead.status == 'C' && wkLead.status_changed?
			wkLead.save
		end
		@wkContact = wkContact
		wkLead
	end

	def candidate_params(rfparams)
		rfparams.permit(:id, :lead_id, :college, :degree, :pass_out)
	end
end
