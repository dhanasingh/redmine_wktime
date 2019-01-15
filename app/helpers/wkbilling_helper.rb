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

module WkbillingHelper
	include WktimeHelper
	include WkgltransactionHelper
	
	# transAmountArr[0] - crLedgerAmtHash, transAmountArr[1] - dbLedgerAmtHash
	# crLedgerAmtHash => key - leger_id, value - crAmount
	# dbLedgerAmtHash => key - leger_id, value - dbAmount
	def postToGlTransaction(transModule, transId, transDate, transAmountArr, currency, description, payInvId)		
		glTransaction = nil
		crLedger = WkLedger.where(:id => transAmountArr[0].keys[0].to_i)
		dbLedger = WkLedger.where(:id => transAmountArr[1].keys[0].to_i)
		unless crLedger[0].blank? || dbLedger[0].blank?
			transType = getTransType(crLedger[0].ledger_type, dbLedger[0].ledger_type)
			if Setting.plugin_redmine_wktime['wktime_currency'] == currency 
				isDiffCur = false 
			else
				isDiffCur = true 
			end
			glTransaction = saveGlTransaction(transModule, transId, transDate, transType, description, transAmountArr, currency, isDiffCur, payInvId)
		end
		glTransaction
	end
	
	# ledgerAmtArr[0] - crLedgerAmtHash, ledgerAmtArr[1] - dbLedgerAmtHash
	# crLedgerAmtHash => key - leger_id, value - crAmount
	# dbLedgerAmtHash => key - leger_id, value - dbAmount
	# inverseModuleArr => Contains the module which has to consider db as cr and cr as db
	def getTransAmountArr(moduleAmtHash, inverseModuleArr)
		crLedgerAmtHash = Hash.new
		dbLedgerAmtHash = Hash.new
		moduleAmtHash.each do |moduleName, amount|
			if inverseModuleArr.blank? || !inverseModuleArr.include?('moduleName')
				crLedger = WkLedger.where(:id => getSettingCfId("#{moduleName}_cr_ledger"))
				dbLedger = WkLedger.where(:id => getSettingCfId("#{moduleName}_db_ledger"))
			else
				crLedger = WkLedger.where(:id => getSettingCfId("#{moduleName}_db_ledger"))
				dbLedger = WkLedger.where(:id => getSettingCfId("#{moduleName}_cr_ledger"))
			end
			crLedgerAmtHash[crLedger[0].id] = amount[0] unless amount[0].blank? || crLedger[0].blank?
			dbLedgerAmtHash[dbLedger[0].id] = amount[1] unless amount[1].blank? || dbLedger[0].blank?
		end
		ledgerAmtArr = [crLedgerAmtHash, dbLedgerAmtHash]
		ledgerAmtArr
	end
	
	def accountPolymormphicHash
		typeHash = {
			'WkAccount' => l(:label_account),
			'WkCrmContact' => l(:label_contact) 
		}
		typeHash
	end
	
	#This method using on Invoice and Payment
	def getProjArrays(parent_id, parent_type)		
		sqlStr = "left outer join projects on projects.id = wk_account_projects.project_id "
		if !parent_id.blank? && !parent_type.blank?
				sqlStr = sqlStr + " where wk_account_projects.parent_id = #{parent_id} and wk_account_projects.parent_type = '#{parent_type}' "
		end
		
		WkAccountProject.joins(sqlStr).select("projects.name as project_name, projects.id as project_id").distinct(:project_id)
	end
	
	def personTypeLabelHash
		typeHash = {
			'A' => l(:label_account),
			'C' => l(:label_contact),
			'S' => l(:label_supplier),
			'SC' => l(:label_supplier_contact) 			
		}
		typeHash
	end
end
