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

class WkbillingController < WkbaseController

before_action :require_login

include WktimeHelper
before_action :check_perm_and_redirect, :only => [:index, :edit, :update, :destroy]

	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_permission
		return validateERPPermission("M_BILL")
	end
	
	def getOrderAccountType
		'A'
	end
	
	def getOrderContactType
		'C'
	end
	
	def getInvoiceType
		'I'
	end
	
	def needBlankProject
		false
	end
	
	def getAdditionalDD
	end	
	
	def getPopulateChkBox	
	end
	
	def isInvGenUnbilledLink
		false
	end
	
	def isInvPaymentLink
		false
	end
	
	def getPaymentController
		"wkpayment"
	end
	
	def addAdditionalTax
		false
	end
	
	def addQuoteFields
		false
	end
	
	def needChangedProject
		true
	end
	
	def editInvNumber
		false
	end
	
	def getOrderNumberPrefix
	end
	
	def getAccountDDLbl
		l(:label_account)
	end
	
	def getNewHeaderLbl
	end
	
	def additionalContactType
		true
	end
end