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

end
