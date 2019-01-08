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

class WkaccountingController < WkbaseController	
  unloadable
	before_filter :require_login
	before_filter :check_perm_and_redirect, :only => [:index, :edit, :update]
	before_filter :check_ac_admin_and_redirect, :only => [:destroy]
	include WkaccountingHelper
	def index
	end
	
	def check_perm_and_redirect
		unless check_permission
			render_403
			return false
		end
	end
	
	def check_ac_admin_and_redirect
	  unless isModuleAdmin('wktime_accounting_admin') 
	    render_403
	    return false
	  end
    end

	def check_permission
		ret = false
		return isModuleAdmin('wktime_accounting_group') || isModuleAdmin('wktime_accounting_admin') 
	end
end
