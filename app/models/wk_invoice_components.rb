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

class WkInvoiceComponents < ApplicationRecord

    has_many :acc_invoice_comps, foreign_key: "invoice_component_id", class_name: "WkAccInvoiceComponents", dependent: :destroy

    scope :getInvComp, ->{
        self.where(comp_type: 'IC')
    }

    scope :getAccInvComp, ->(id){
        joins("LEFT JOIN wk_acc_invoice_components AIC on wk_invoice_components.id = AIC.invoice_component_id and (account_project_id IN (#{id}) OR AIC.id is NULL)"+get_comp_con('AIC'))
        .select("wk_invoice_components.id as ic_id, wk_invoice_components.name, wk_invoice_components.value as ic_value, AIC.*")
    }
end
