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

class WkAccountProject < ApplicationRecord


  include Redmine::SafeAttributes

  safe_attributes(
    "parent_id",
    "parent_type",
    "project_id",
    "itemized_bill",
    "billing_type"
  )

  belongs_to :project

  belongs_to :parent, :polymorphic => true
  has_one :wkaccount, -> { where(:wk_account_projects => {parent_type: 'WkAccount'}) },
    class_name: 'WkAccount', foreign_key: 'id', primary_key: 'parent_id'
  has_one :wkcontact, -> { where(:wk_account_projects => {parent_type: 'WkCrmContact'}) },
    class_name: 'WkCrmContact', foreign_key: 'id', primary_key: 'parent_id'

  has_many :wk_billing_schedules, foreign_key: "account_project_id", class_name: "WkBillingSchedule", :dependent => :destroy
  has_many :wk_acc_project_taxes, foreign_key: "account_project_id", class_name: "WkAccProjectTax", :dependent => :destroy
  has_many :taxes, through: :wk_acc_project_taxes
  has_many :acc_invoice_comps, foreign_key: "account_project_id", class_name: "WkAccInvoiceComponents", dependent: :destroy
  #validates_uniqueness_of :project_id, :scope => :account_id
  validates_uniqueness_of :project_id,  :scope => [:parent_id, :parent_type]

  scope :getAccProj, ->(parent_id, parent_type){ where(parent_id: parent_id, parent_type: parent_type) }

  scope :getAccByProjID, ->(project_id){ where(project_id: project_id) }

  scope :getTax, ->(id, parent_type, parent_id){
    where("project_id = ?  and parent_id = ? and parent_type = ? ", id, parent_id, parent_type)
  }
end
