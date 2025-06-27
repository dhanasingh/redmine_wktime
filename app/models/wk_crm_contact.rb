# ERPmine - ERP for service industry
# Copyright (C) 2011-2021  Adhi software pvt ltd
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

class WkCrmContact < ApplicationRecord

  belongs_to :account, class_name: 'WkAccount'
  has_many :billable_projects, as: :parent, class_name: "WkAccountProject", dependent: :destroy
  belongs_to :address, class_name: 'WkAddress', dependent: :destroy
  belongs_to :assigned_user, class_name: 'User'
  has_one :lead, foreign_key: 'contact_id', class_name: 'WkLead', dependent: :destroy
  has_many :activities, as: :parent, class_name: 'WkCrmActivity', dependent: :destroy
  has_many :opportunities, as: :parent, class_name: 'WkOpportunity', dependent: :destroy
  has_many :projects, through: :billable_projects
  has_many :contracts, as: :parent, class_name: "WkContract", dependent: :destroy
  has_many :invoices, as: :parent, class_name: "WkInvoice", dependent: :restrict_with_error
  has_many :invoice_items, through: :invoices
  has_many :contacts, foreign_key: "contact_id", class_name: "WkCrmContact"
  has_many :spent_fors, as: :spent_for, class_name: 'WkSpentFor', dependent: :restrict_with_error
  belongs_to :location, class_name: 'WkLocation'
  has_one :wkuser, as: :source, class_name: "WkUser", dependent: :restrict_with_error

  validates_presence_of :last_name
   # Different ways of displaying/sorting users
  NAME_FORMATS = {
    firstname_lastname: {
        string: '#{first_name} #{last_name}',
        order: %w(first_name last_name id),
        setting_order: 1
      },
    firstname_lastinitial: {
        string: '#{first_name} #{last_name.to_s.chars.first}.',
        order: %w(first_name last_name id),
        setting_order: 2
      },
    firstinitial_lastname: {
        string: '#{first_name.to_s.gsub(/(([[:alpha:]])[[:alpha:]]*\.?)/, \'\2.\')} #{last_name}',
        order: %w(first_name last_name id),
        :setting_order => 2
      },
    :first_name => {
        :string => '#{first_name}',
        :order => %w(first_name id),
        :setting_order => 3
      },
    :lastname_firstname => {
        :string => '#{last_name} #{first_name}',
        :order => %w(last_name first_name id),
        :setting_order => 4
      },
    :lastnamefirstname => {
        :string => '#{last_name}#{first_name}',
        :order => %w(last_name first_name id),
        :setting_order => 5
      },
    :lastname_comma_firstname => {
        :string => '#{last_name}, #{first_name}',
        :order => %w(last_name first_name id),
        :setting_order => 6
      },
    :last_name => {
        :string => '#{last_name}',
        :order => %w(last_name id),
        :setting_order => 7
      },
    :username => {
        :string => '#{login}',
        :order => %w(login id),
        :setting_order => 8
      },
  }

  # Return user's full name for display
  def name(formatter = nil)
    f = self.class.name_formatter(formatter)
    if formatter
      eval('"' + f[:string] + '"')
    else
      @name ||= eval('"' + f[:string] + '"')
    end
  end

  # Returns contact's contracts for the given project
  # or nil if the contact do not have contract
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

  def self.name_formatter(formatter = nil)
    NAME_FORMATS[formatter] || NAME_FORMATS[:firstname_lastname]
  end

  def self.total_invoice_payable_for(parent_type, parent_id, invoice_type)
    parent = parent_type.constantize.find_by(id: parent_id)
    return { amount: 0.0, currency: "" } unless parent.present?

    invoice_ids = WkInvoice.where(parent: parent, invoice_type: invoice_type).pluck(:id)
    return { amount: 0.0, currency: "" } unless invoice_ids.present?
    total_invoiced = WkInvoiceItem.where(invoice_id: invoice_ids).sum(:amount)
    total_paid     = WkPaymentItem.where(invoice_id: invoice_ids, is_deleted: false).sum(:amount)
    currency       = WkInvoiceItem.where(invoice_id: invoice_ids).limit(1).pick(:currency) || ""

    { amount: total_invoiced - total_paid, currency: currency }
  end

  def has_billable_projects?
    billable_projects.exists?
  end
end
