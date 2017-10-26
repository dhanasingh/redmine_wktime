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

class WkAssetDepreciation < ActiveRecord::Base
  unloadable
  belongs_to :inventory_item, :class_name => 'WkInventoryItem'
  belongs_to :gl_transaction , :class_name => 'WkGlTransaction'
  before_destroy :remove_entry_from_gl_transaction
  
  def remove_entry_from_gl_transaction
	unless self.gl_transaction_id.blank?
		ledgerId = self.inventory_item.product_item.product.ledger_id
		depLedgerId = Setting.plugin_redmine_wktime['wktime_depreciation_ledger']
		unless ledgerId.blank? || depLedgerId.blank?
			detailCount = self.gl_transaction.transaction_details.count
			productTransDetail = self.gl_transaction.transaction_details.where(:ledger_id => ledgerId)
			depTransDetail = self.gl_transaction.transaction_details.where(:ledger_id => depLedgerId)
			unless productTransDetail[0].blank? || depTransDetail[0].blank?
				if detailCount > 2
					depTransDetail[0].amount = depTransDetail[0].amount - self.depreciation_amount
					depTransDetail[0].save
					productTransDetail[0].destroy
				else
					self.gl_transaction.destroy
				end
			end
		end
	end
  end
 
end