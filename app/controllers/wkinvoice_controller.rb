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

class WkinvoiceController < WkorderentityController

	
	def previewBilling(accountProjects)
		lastParentId = 0
		@currency = nil
		@listKey = 0
		@invList = Hash.new{|hsh,key| hsh[key] = {} }
		@previewBilling = true
		isActBilling = false
		totalInvAmt = 0
		accountProjects.each do |accProj|
			if isAccountBilling(accProj) 
				if lastParentId != accProj.parent_id
					setTempInvoice(@from, @to, accProj.parent_id, accProj.parent_type, '1', '0')
					isActBilling = true
				end
				lastParentId = accProj.parent_id
			else
				isActBilling = false
				setTempInvoice(@from, @to, accProj.parent_id, accProj.parent_type, '1', accProj.project_id)
			end
			
			if  (!@invList[@listKey]['amount'].blank? && @invList[@listKey]['amount'] != 0.0) 
				totQuantity = 0
				@invItems.each do |key, value|
					totQuantity = totQuantity + value['item_quantity'] unless value['item_quantity'].blank?
				end
				@invList[@listKey].store 'invoice_number', ""
				@invList[@listKey].store 'parent_type', accProj.parent_type
				@invList[@listKey].store 'parent_id', accProj.parent_id
				@invList[@listKey].store 'name', accProj.parent.name
				@invList[@listKey].store 'project', accProj.project.name
				@invList[@listKey].store 'project_id', accProj.project_id
				@invList[@listKey].store 'status', 'o'
				@invList[@listKey].store 'quantity', totQuantity
			#	@invList[@listKey].store 'invoice_date', Date.today
				@invList[@listKey].store 'start_date', @from
				@invList[@listKey].store 'end_date', @to
				@invList[@listKey].store 'isAccountBilling', isActBilling
				totalInvAmt = totalInvAmt + @invList[@listKey]['amount']
			#	@invList[@listKey].store 'modified_by', User.current
				@listKey = @listKey + 1
			end
		end	
		@entry_count = @invList.size
		setLimitAndOffset()
		invTotal = 0
		totlist = @invList.first(@limit*@entry_pages.page).last(@limit)
		totlist.each do |key, value|
			unless value.empty?
				invTotal = invTotal + value['amount'].to_i unless value['amount'].blank?
			end
		end
		@totalInvAmt = invTotal #totalInvAmt
	end
	
	def deleteBilledEntries(invItemIdsArr)
		CustomField.find(getSettingCfId('wktime_billing_id_cf')).custom_values.where(:value => invItemIdsArr).delete_all unless getSettingCfId('wktime_billing_id_cf').blank? || getSettingCfId('wktime_billing_id_cf') == 0
	end
	
	def getInvoiceType
		'I'
	end
	
	def isPopulateCheckBox
		true
	end
	
	def isPopulateCheckBoxLabel
		l(:label_populate_unbilled_items)
	end
	
	def requireRfqDD
		false
	end

end