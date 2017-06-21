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

class WkquoteController < WksupplierorderentityController
  unloadable
	
	def getInvoiceType
		'Q'
	end
	
	def getLabelInvNum
		l(:label_quote_number)
	end
	
	def getLabelNewInv
		l(:label_new_quote)
	end
	
	def getHeaderLabel
		l(:label_quotes)
	end
	
	def getItemLabel
		l(:label_quote_items)
	end
	
	def getDateLbl
		l(:label_quote_date)
	end
end
