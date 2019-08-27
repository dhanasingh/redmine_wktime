# ERPmine - ERP for service industry
# Copyright (C) 2011-2017  Adhi software pvt ltd
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
class WksupplierpaymentController < WkpaymententityController
  unloadable
  menu_item :wkrfq
  
	def getOrderAccountType
		'S'
	end
	
	def getInvoiceType
		'SI'
	end
	
	def getItemLabel
		l(:label_supplier_payment)
	end
	
	def getEditHeaderLabel
		l(:label_supplier_payment)
	end
	
	def getOrderContactType
		'SC'
	end
	
	def getAuotPostId
		'supplier_invoice_auto_post_gl'
	end
	
	def getAutoPostModule
		'supplier_payment'
	end

	def getAccountDDLbl
		l(:label_supplier_account)
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

end
