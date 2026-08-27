# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
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

class WksuppliercontactController < WkcontactController

	menu_item :wkrfq
	accept_api_auth :index, :edit, :update
  before_action :init_survey

	include WktimeHelper

	before_action :init_survey

	def init_survey
		@survey_ctrl = "wksurvey"
		@survey_perm = validateERPPermission("E_SUR")
	end

	def getContactType
		'SC'
	end

	def getContactController
		'wksuppliercontact'
	end

	def getAccountType
		'S'
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

	def deletePermission
		validateERPPermission("A_PUR_PRVLG")
	end

	def getAccountLbl
		l(:label_supplier_account)
	end

	def lblNewContact
		l(:label_new_item, l(:label_supplier_contact))
	end

	def contactLbl
		l(:label_supplier_contact)
	end

	def init_survey
		@survey_ctrl = "wksurvey"
		@survey_perm = validateERPPermission("E_SUR")
	end

end
