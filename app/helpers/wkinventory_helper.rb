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

module WkinventoryHelper
	include WktimeHelper

	def getProductTypeHash(needBlank)		
		productType = { 'I'  => l(:label_inventory), 'A' =>  l(:label_asset) }
		if needBlank
			productType = { '' => "", 'I'  => l(:label_inventory), 'A' =>  l(:label_asset) }
		end
		additionalProducts = call_hook :additional_product_type
		unless additionalProducts.blank?
			if additionalProducts.is_a?(Array) 
				additionalProducts.each do | hsh |
					productType =  productType.merge(hsh)
				end
			else
				mergeHash = eval(additionalProducts)
				productType =  productType.merge(mergeHash)
			end
		end
		productType
	end
	
	def getDepreciationTypeHash(needBlank)		
		productType = { 'SL'  => l(:label_stright_line), 'WDV' =>  l(:label_wdv) }
		if needBlank
			productType = { '' => "", 'SL'  => l(:label_stright_line), 'WDV' =>  l(:label_wdv) }
		end
		productType
	end
	
	def getFrequencyMonth(periodType)
		val = nil
		case periodType
		when 'a'
		  val = 12
		when 'sa'
		  val = 6
		when 'q'
		  val = 3
		when 'm'
		  val = 1
		else
		  raise ArgumentError, 'invalid arguments to period'
		end
		val
	end
end
