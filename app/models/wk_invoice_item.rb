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

class WkInvoiceItem < ApplicationRecord

  include Redmine::SafeAttributes
  belongs_to :invoice, :class_name => 'WkInvoice'
  belongs_to :modifier, :class_name => 'User'
  belongs_to :project
  has_many :account_project, through: :project
  has_many :spent_fors, foreign_key: "invoice_item_id", class_name: "WkSpentFor", :dependent => :nullify
  belongs_to :invoice_item, :polymorphic => true
  belongs_to :product, class_name: "WkProduct"
  has_many :inventory_items, class_name: "WkInventoryItem", foreign_key: "invoice_item_id"
  has_many :consumed_items, as: :consumer, class_name: "WkConsumedItems", dependent: :destroy

  validates_presence_of :invoice_id
  validates_numericality_of :amount, :allow_nil => true, :message => :invalid
  validates_numericality_of :quantity, :allow_nil => true, :message => :invalid
  validates_numericality_of :rate, :allow_nil => true, :message => :invalid

  def self.getUnbilledTimeEntries(project_id, start_date, end_date, parent_id, parent_type, model=TimeEntry)
    model.includes(:spent_for).where(project_id: project_id, spent_on: start_date .. end_date, wk_spent_fors: { spent_for_type: [parent_type, nil], spent_for_id: [parent_id, nil], invoice_item_id: nil })
  end

  def self.getGenerateEntries(toVal, fromVal, parent_id, parent_type, projectID, model, table)
    entries = model.joins(:spent_for, :project)
    .joins("INNER JOIN wk_account_projects ON wk_account_projects.project_id = #{table}.project_id"+get_comp_con('wk_account_projects'))
    .where(spent_on: fromVal .. toVal, wk_spent_fors: { invoice_item_id: nil })
    .select("#{table}.*, wk_account_projects.parent_id, wk_account_projects.parent_type")
    entries = entries.where(wk_account_projects: { parent_type: parent_type}) if parent_type.present?
    entries = entries.where(wk_account_projects: { parent_id: parent_id}) if parent_id.present?
    #Added Expense config
    entries = entries.where(wk_account_projects: {include_expense: true}) if table == "wk_expense_entries"
    entries = entries.where(wk_account_projects: { billing_type: 'TM'}) if table != "wk_expense_entries"
    entries = getNonZeroEntries(entries, table)
    entries = getFilteredEntries(entries, projectID, parent_type)
    entries = entries.where("(wk_spent_fors.spent_for_id= #{parent_id} AND wk_spent_fors.spent_for_type = '#{parent_type}') OR wk_spent_fors.spent_for_id is NULL") if parent_id.present?
    entries.order("#{table}.spent_on desc")
  end

  def self.getFcItems(fromVal, toVal, projectID, parent_id, parent_type)
    fcEntries = WkAccountProject.joins(:project, :wk_billing_schedules)
    .where(wk_billing_schedules: {bill_date: fromVal .. toVal, invoice_id: nil})
    .select("wk_account_projects.*,wk_billing_schedules.*")
    fcEntries = fcEntries.where(parent_type: parent_type) if parent_type.present?
    fcEntries = fcEntries.where(parent_id: parent_id) if parent_id.present?
    fcEntries = getFilteredEntries(fcEntries, projectID, parent_type)
    fcEntries.order("wk_billing_schedules.bill_date desc")
  end

  def self.getFilteredEntries(entries, projectID, parent_type)
    entries = entries.where(projects: {id: projectID}) if projectID.present? && projectID != "0"
    entries = entries.joins("LEFT JOIN wk_accounts ON wk_accounts.id = wk_account_projects.parent_id AND parent_type = 'WkAccount' "+get_comp_con('wk_accounts')+"
    LEFT JOIN wk_crm_contacts ON wk_crm_contacts.id = wk_account_projects.parent_id AND parent_type = 'WkCrmContact' "+get_comp_con('wk_crm_contacts')).select("wk_accounts.name AS name, CONCAT(wk_crm_contacts.first_name,' ',wk_crm_contacts.last_name) AS c_name") if parent_type == ''
    entries = entries.joins("INNER JOIN wk_accounts ON wk_accounts.id = wk_account_projects.parent_id AND parent_type = 'WkAccount' "+get_comp_con('wk_accounts')).select("wk_accounts.name AS name") if parent_type == 'WkAccount'
    entries = entries.joins("INNER JOIN wk_crm_contacts ON wk_crm_contacts.id = wk_account_projects.parent_id AND parent_type = 'WkCrmContact'"+get_comp_con('wk_crm_contacts')).select("CONCAT(wk_crm_contacts.first_name,' ',wk_crm_contacts.last_name) AS name") if parent_type == 'WkCrmContact'
    entries
  end

  def self.filterByIssues(entries, issue_id, project_id, parent_id, parent_type)
    accProj = WkAccountProject.where(project_id: project_id, parent_id: parent_id, parent_type: parent_type).first
    entries = entries.where(:issue_id => issue_id) if issue_id > 0
    entries = entries.where(:issue_id => nil) if issue_id == 0 && accProj && accProj&.itemized_bill
    entries = entries.order("spent_on desc")
    entries
  end

  def self.getNonZeroEntries(entries, table)
    if table == "time_entries"
      entries = entries.where("time_entries.hours > 0")
    elsif table == "wk_material_entries"
      entries = entries.where("wk_material_entries.selling_price > 0")
    elsif table == "wk_expense_entries"
      entries = entries.where("wk_expense_entries.amount > 0")
    end
    entries
  end

  scope :getInvItemsFromInvoice, ->(invoice_id){ self.where(invoice_id: invoice_id).where("item_type NOT IN ('t','r')") }
end
