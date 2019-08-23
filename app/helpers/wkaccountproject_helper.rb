# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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

module WkaccountprojectHelper

include WktimeHelper
include WkinvoiceHelper
include WkcrmHelper

	def saveBillableProjects(id, projectId, parentId, parentType, applyTax, itemizedBill, billingType)
		if !id.blank?
			wkaccountproject = WkAccountProject.find(id.to_i)
		else
			wkaccountproject = WkAccountProject.new
		end
		
		wkaccountproject.project_id = projectId.to_i
		wkaccountproject.parent_id = parentId.to_i
		wkaccountproject.parent_type = parentType
		wkaccountproject.apply_tax = applyTax
		wkaccountproject.itemized_bill = itemizedBill
		wkaccountproject.billing_type = billingType
		
		if !wkaccountproject.save			
			errorMsg = wkaccountproject.errors.full_messages.join("<br>")
		end
		wkaccountproject
	end

	def accountProjctList
		
		sqlwhere = ""
		if controller_name == "wkaccountproject"
			filter_type = session[controller_name].try(:[], :polymorphic_filter)
			contact_id = session[controller_name].try(:[], :contact_id)
			account_id = session[controller_name].try(:[], :account_id)
			projectId = params[:project_id]
		else
			filter_type = nil
			contact_id = params[:contact_id]
			account_id = params[:account_id]
			projectId = params[:project_id]
		end
		if !projectId.blank?
			sqlwhere += " identifier = '#{projectId}' "
		end
		if filter_type == '2' || (filter_type.blank? && !contact_id.blank?)
			sqlwhere += " and "  unless sqlwhere.blank?
			sqlwhere += " wk_account_projects.parent_type = 'WkCrmContact' "
			sqlwhere += " and wk_account_projects.parent_id = '#{contact_id}' " unless contact_id.blank?
		end
		
		if filter_type == '3' || (filter_type.blank? && !account_id.blank?)
			sqlwhere += " and "  unless sqlwhere.blank?
			sqlwhere += " wk_account_projects.parent_type = 'WkAccount' "
			sqlwhere += " and wk_account_projects.parent_id = '#{account_id}' " unless account_id.blank?
		end
		entries = WkAccountProject.joins("INNER JOIN projects ON projects.id = project_id")
		entries = entries.where(sqlwhere) unless sqlwhere.blank?
		entries
	end
	
    def set_filter_session
		session[controller_name] = {:project_id => params[:project_id]} if session[controller_name].nil?
		if params[:searchlist] == controller_name
			filters = [:contact_id, :account_id, :polymorphic_filter]
			filters.each do |param|
				if params[param].blank? && session[controller_name].try(:[], param).present?
					session[controller_name].delete(param)
				elsif params[param].present?
					session[controller_name][param] = params[param]
				end
			end
		end
   end

   def get_project_id(project_id=params[:project_id])
    projectEntry = Project.where(:identifier => project_id)	
	projectEntry = projectEntry.first unless projectEntry.blank?
	projectId  = projectEntry.id
   end
end
