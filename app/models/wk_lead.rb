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

class WkLead < ApplicationRecord

  has_many :activities, as: :parent, class_name: 'WkCrmActivity', :dependent => :destroy
  belongs_to :account, :class_name => 'WkAccount'
  belongs_to :created_by_user, :class_name => 'User'
  belongs_to :address, :class_name => 'WkAddress'
  belongs_to :contact, :class_name => 'WkCrmContact', :dependent => :destroy
  belongs_to :referred, foreign_key: "referred_by", primary_key: "id", class_name: "User"
  has_one :candidate, class_name: "WkCandidate", foreign_key: "lead_id", dependent: :destroy
  has_many :notifications, as: :source, class_name: "WkUserNotification", :dependent => :destroy
  accepts_nested_attributes_for :candidate, allow_destroy: true
  has_many :billable_projects, as: :parent, class_name: "WkAccountProject", :dependent => :destroy
  has_many :projects, through: :billable_projects
  has_many :location, through: :contact
  belongs_to :lead_source, -> { where(wk_crm_enumerations: {enum_type: 'LS'}) }, foreign_key: 'lead_source_id', :class_name => 'WkCrmEnumeration'

  before_save :update_status_update_on
  after_create_commit :send_notification
  after_save :lead_notification

  acts_as_attachable :view_permission => :view_files,
                    :edit_permission => :manage_files,
                    :delete_permission => :manage_files

  scope :filter_name, ->(name){
    where("LOWER(wk_crm_contacts.first_name) LIKE '%#{name.downcase}%' OR LOWER(wk_crm_contacts.last_name) LIKE '%#{name.downcase}%'")
  }

  scope :filter_status, ->(status){
    where(status: status)
  }

  scope :filter_location, ->(location_id){
    where("wk_crm_contacts.location_id" => location_id)
  }

  scope :hiring_employees, ->{
    joins(:contact)
    .joins("LEFT JOIN wk_users ON wk_users.source_id = wk_leads.contact_id" +get_comp_con('wk_users'))
    .where("wk_crm_contacts.contact_type" => "IC", "wk_leads.status" => "C", "wk_users.source_id" => nil)
  }

  def self.referrals(privilege, id=nil)
    referrals = WkLead.joins("RIGHT JOIN wk_crm_contacts ON wk_crm_contacts.id = wk_leads.contact_id " +get_comp_con('wk_crm_contacts')).
    joins("LEFT JOIN wk_candidates ON wk_leads.id = lead_id"+get_comp_con('wk_candidates')).
    where("wk_crm_contacts.contact_type": "IC").
    order("wk_crm_contacts.updated_at desc")
    referrals = referrals.where(referred_by: User.current.id) unless privilege
    referrals = referrals.where(id: id) if id.present?
    referrals
  end

  def update_status_update_on
	  self.status_update_on = DateTime.now if status_changed?
  end

  def name
	  contact.name unless contact.blank?
  end

  def lead_notification
    if status? && status == "C" && WkNotification.notify('leadConverted')
      label = self.contact.contact_type == 'C'? l(:label_lead) : l(:label_referral)
      emailNotes = label+ ": " + (self.account ? self.account.name : self.contact.name)+" "+l(:label_has_converted)+" "+ "\n\n" + l(:label_redmine_administrator)
      subject = label + " " + l(:label_notification)
      userId = (WkPermission.permissionUser('B_CRM_PRVLG') + WkPermission.permissionUser('A_CRM_PRVLG')).uniq
      WkNotification.notification(userId, emailNotes, subject, self, 'leadConverted')
    end
  end

  def send_notification
    if WkNotification.notify('leadGenerated')
      label = self.contact.contact_type == 'C'? l(:label_lead) : l(:label_referral)
      emailNotes = label+ ": " + (self.account ? self.account.name : self.contact.name) +" "+l(:label_has_created)+" "+ "\n\n" + l(:label_redmine_administrator)
      subject = label + " " + l(:label_notification)
      userId = (WkPermission.permissionUser('B_CRM_PRVLG') + WkPermission.permissionUser('A_CRM_PRVLG')).uniq
      WkNotification.notification(userId, emailNotes, subject, self, 'leadGenerated')
      if self.contact.contact_type == 'IC'
        emailNotes = l(:label_candidate_mail) + "\n\n" +l(:label_referred_by)+" "+ self.referred.name
        subject = l(:label_referral) + " " + l(:label_notification)
        candidateMail = self.contact&.address&.email
        WkMailer.email_user(subject, User.current.language, candidateMail, emailNotes, nil).deliver_later
      end
    end
  end

  def self.getLeadEntries(from, to, userIdArr)
    entries = self.includes(:contact).where(:created_at => from .. to, wk_crm_contacts: { contact_type: 'C' })
    entries = entries.where(wk_crm_contacts: {assigned_user_id: userIdArr }) if userIdArr.present?
    entries
  end

  scope :filter_pass_out, ->(pass_out){ where("wk_candidates.pass_out" => pass_out) }

  def address
	  contact.address unless contact.blank?
  end
end
