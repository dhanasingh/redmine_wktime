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

class WkInvoiceItem < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  belongs_to :invoice, :class_name => 'WkInvoice'
  belongs_to :modifier, :class_name => 'User'
  belongs_to :project
  # has_many :material_entries, foreign_key: "invoice_item_id", class_name: "WkMaterialEntry", :dependent => :nullify
  has_many :spent_fors, foreign_key: "invoice_item_id", class_name: "WkSpentFor", :dependent => :nullify
  
  # attr_protected :modifier_id
  
  validates_presence_of :invoice_id
  validates_numericality_of :amount, :allow_nil => true, :message => :invalid
  validates_numericality_of :quantity, :allow_nil => true, :message => :invalid
  validates_numericality_of :rate, :allow_nil => true, :message => :invalid

  scope :getSpentForEntries, ->(id){
    joins(:spent_fors, :project)
    .joins("INNER JOIN time_entries AS TE ON TE.id = wk_spent_fors.spent_id AND spent_type = 'TimeEntry'")
    .joins("INNER JOIN users AS U ON U.id = TE.user_id AND U.type IN ('User', 'AnonymousUser')")
    .joins("INNER JOIN issues AS I ON I.id = TE.issue_id")
    .select("TE.*, U.firstname, U.lastname, projects.name AS proj_name, I.subject").where("wk_spent_fors.invoice_item_id =  ? ", id )
    .order("U.firstname asc, TE.spent_on desc")
  }

  def self.getUnbilledTimeEntries(project_id, start_date, end_date, parent_id, parent_type)
    TimeEntry.includes(:spent_for).where(project_id: project_id, spent_on: start_date .. end_date, wk_spent_fors: { spent_for_type: [parent_type, nil], spent_for_id: [parent_id, nil], invoice_item_id: nil })
  end

  def self.getGenerateEntries(toVal, fromVal, parent_id, parent_type, projectID, model, table)
    entries = model.joins(:spent_for, :project)
    .joins("INNER JOIN wk_projects ON wk_projects.project_id = #{table}.project_id")
    .joins("INNER JOIN wk_account_projects ON wk_account_projects.project_id = wk_projects.project_id")
    .where(wk_spent_fors: { invoice_item_id: nil }, wk_account_projects: { billing_type: 'TM'}, wk_projects: { is_billable: true }) 
    .select("#{table}.*, wk_account_projects.parent_id, wk_account_projects.parent_type")
    entries = entries.where("#{table}.spent_on <= ?", toVal)
    entries = entries.where(wk_account_projects: { parent_type: parent_type}) if parent_type.present?
    entries = entries.where(wk_account_projects: { parent_id: parent_id}) if parent_id.present?

    entries = entries.where(projects: {id: projectID}) if projectID.present? && projectID != "0"
    entries = entries.joins("INNER JOIN wk_accounts ON wk_accounts.id = wk_account_projects.parent_id").select("wk_accounts.name AS name") if parent_type == 'WkAccount' || parent_type == ''
    entries = entries.joins("INNER JOIN wk_crm_contacts ON wk_crm_contacts.id = wk_account_projects.parent_id").select("wk_crm_contacts.last_name AS name") if parent_type == 'WkCrmContact'  || parent_type == ''
    entries
  end
end
