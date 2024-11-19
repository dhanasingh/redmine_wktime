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

class WksupplierorderentityController < WkorderentityController


	def newOrderEntity(parentId, parentType)
		newSupOrderEntity(parentId, parentType)
	end

	def newSupOrderEntity(parentId, parentType)
		msg = ""

		unless params[:rfq_id].blank?
			@rfqObj = WkRfq.find(params[:rfq_id].to_i)
		end
			if !params[:project_id].blank? && params[:project_id] != '0'
				@projectsDD = Project.where(:id => params[:project_id].to_i).pluck(:name, :id)
			end

			@currency = params[:inv_currency]
			setTempEntity(params[:start_date], params[:end_date], parentId, parentType, params[:populate_items], params[:project_id])

	end

	def getOrderAccountType
		'S'
	end

	def getOrderContactType
		'SC'
	end

	def needBlankProject
		false
	end

	def addAdditionalTax
		true
	end

	def needChangedProject
		false
	end

	def getAccountDDLbl
		l(:label_supplier_account)
	end

	def getSupplierAddress(invoice)
		invoice.parent.name + "\n" + (invoice.parent.address.blank? ? "" : invoice.parent.address.fullAddress) + (invoice&.parent_type == 'WkAccount' ? "\n" + "GST No: " + invoice&.parent&.tax_number.to_s : "")
	end

	def getCustomerAddress(invoice)
		getMainLocation + "\n" +  getAddress
	end

	def getPaymentController
		"wksupplierpayment"
	end

	def deletePermission
		validateERPPermission("A_PUR_PRVLG")
	end

	def check_permission
		return validateERPPermission("B_PUR_PRVLG") || validateERPPermission("A_PUR_PRVLG")
	end

	def check_crm_admin_and_redirect
	  unless validateERPPermission("A_PUR_PRVLG")
	    render_403
	    return false
	  end
    end

	def getAccountLbl
		l(:label_supplier_account)
	end

	def additionalContactType
		false
	end

	def additionalAccountType
		false
	end

	def addUnbilledItems
		false
	end
end
