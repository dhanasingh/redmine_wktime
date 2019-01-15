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

class WkCrmContact < ActiveRecord::Base
  unloadable
  belongs_to :account, :class_name => 'WkAccount'
  has_many :billable_projects, as: :parent, class_name: "WkAccountProject", :dependent => :destroy
  belongs_to :address, :class_name => 'WkAddress', :dependent => :destroy
  belongs_to :assigned_user, :class_name => 'User'
  has_one :lead, foreign_key: 'contact_id', class_name: 'WkLead', :dependent => :destroy
  has_many :activities, as: :parent, class_name: 'WkCrmActivity', :dependent => :destroy
  has_many :opportunities, as: :parent, class_name: 'WkOpportunity', :dependent => :destroy
  has_many :projects, through: :billable_projects
  has_many :contracts, as: :parent, class_name: "WkContract", :dependent => :destroy
  has_many :invoices, as: :parent, class_name: "WkInvoice", :dependent => :restrict_with_error
  has_many :invoice_items, through: :invoices
  has_many :contacts, foreign_key: "contact_id", class_name: "WkCrmContact"
  has_many :spent_fors, as: :spent_for, class_name: 'WkSpentFor', :dependent => :restrict_with_error
  belongs_to :location, :class_name => 'WkLocation'
   
  validates_presence_of :last_name
   # Different ways of displaying/sorting users
  NAME_FORMATS = {
    :firstname_lastname => {
        :string => '#{first_name} #{last_name}',
        :order => %w(first_name last_name id),
        :setting_order => 1
      },
    :firstname_lastinitial => {
        :string => '#{first_name} #{last_name.to_s.chars.first}.',
        :order => %w(first_name last_name id),
        :setting_order => 2
      },
    :firstinitial_lastname => {
        :string => '#{first_name.to_s.gsub(/(([[:alpha:]])[[:alpha:]]*\.?)/, \'\2.\')} #{last_name}',
        :order => %w(first_name last_name id),
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
  def contract(project)
		contract = contracts.where(:project_id => project.id).first
		contract = contracts[0] if contract.blank?
		contract
  end

  def self.name_formatter(formatter = nil)
    NAME_FORMATS[formatter] || NAME_FORMATS[:firstname_lastname]
  end
end
