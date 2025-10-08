# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
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

class WkAccount < ApplicationRecord

  include Redmine::SafeAttributes

  safe_attributes(
    'name',
    'account_type',
    'account_bllling',
    'address_id',
    'activity_id',
    'account_category',
    'account_number',
    'tax_number',
    'industry',
    'description',
    'annual_revenue',
    'location_id',
    'assigned_user_id'
  )
  belongs_to :address, :class_name => 'WkAddress', :dependent => :destroy
  has_many :billable_projects, as: :parent, class_name: "WkAccountProject", :dependent => :destroy
  has_many :invoices, as: :parent, class_name: "WkInvoice", :dependent => :restrict_with_error
  has_many :invoice_items, through: :invoices
  has_many :projects, through: :billable_projects
  has_many :contracts, as: :parent, class_name: "WkContract", :dependent => :destroy
  has_many :opportunities, as: :parent, class_name: "WkOpportunity", :dependent => :destroy
  has_many :activities, as: :parent, class_name: 'WkCrmActivity', :dependent => :destroy
  has_many :contacts, foreign_key: "account_id", class_name: "WkCrmContact", :dependent => :destroy
  has_many :payments, as: :parent, class_name: "WkPayment"
  belongs_to :location, :class_name => 'WkLocation'
  has_many :spent_fors, as: :spent_for, class_name: 'WkSpentFor', :dependent => :restrict_with_error
  validates_presence_of :name
  validate :hasAnyValues

  def hasAnyValues
	name.blank? && address_id.blank? && activity_id.blank? && industry.blank? && annual_revenue.blank? && assigned_user_id.blank? && id.blank?
  end

  # Returns account's contracts for the given project
  # or nil if the account do not have contract
  def contract(project, invEndDate)
    contract = nil
    if project.present?
      contract = self.get_contract(project.id, invEndDate)
      if contract.blank?
        #parent Project ids
        projectID = Project.active.where("lft < #{project.lft} AND rgt > #{project.rgt}").order(lft: "desc").pluck(:id)
        projectID.each do |id|
          break if contract.present?
          contract = self.get_contract(id, invEndDate)
        end
      end
    end
    contract
  end

  def get_contract(projectId, invEndDate)
    wkcontracts = contracts.where(project_id: projectId).order(start_date: "desc")
    contract = wkcontracts.where("start_date < ? AND (end_date IS NULL OR end_date > ?)", invEndDate, invEndDate).first
    contract = wkcontracts.first if contract.blank?
    contract
  end

  def has_billable_projects?
    billable_projects.exists?
  end
end
