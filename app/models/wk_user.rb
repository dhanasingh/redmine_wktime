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

class WkUser < ApplicationRecord
  include Redmine::SafeAttributes
  serialize :others
  require 'yaml'

  safe_attributes 'role_id', 'id1','id2', 'id3', 'join_date', 'birth_date', 'termination_date',  'gender', 'bank_name','account_number',
  'bank_code', 'loan_acc_number', 'tax_id', 'ss_id', 'custom_number1', 'custom_number2','custom_date1', 'custom_date2', 'is_schedulable',
  'billing_rate', 'billing_currency', 'location_id', 'department_id', 'address_id', 'shift_id', 'created_by_user_id', 'updated_by_user_id',
  'source_id', 'source_type', 'retirement_account', 'marital_id', 'state_insurance','employee_id', 'emerg_type_id',
  'emergency_contact', 'dept_section_id', 'notes'

  belongs_to :user
  belongs_to :role
  belongs_to :location, :class_name => 'WkLocation'
  belongs_to :department, :class_name => 'WkCrmEnumeration'
  belongs_to :address, :foreign_key => 'address_id', :dependent => :destroy, :class_name => 'WkAddress'
  belongs_to :source, polymorphic: true
  belongs_to :shift, class_name: "WkShift"
  belongs_to :emerg_type, :class_name => 'WkCrmEnumeration'
  belongs_to :dept_section, :class_name => 'WkCrmEnumeration'
  belongs_to :marital, :class_name => 'WkCrmEnumeration'
  before_save :encrypt_user_credentials

	def save_address
		self.address ||= WkAddress.new(:wk_user => self)
	end

  def encrypt_user_credentials
    key = YAML::load_file(Rails.root+'plugins/redmine_wktime/config/config.yml')
    crypt = ActiveSupport::MessageEncryptor.new(key['encryption_key'])
    self.account_number = crypt.encrypt_and_sign(self.account_number) if account_number_changed?
    self.tax_id = crypt.encrypt_and_sign(self.tax_id) if tax_id_changed?
    self.ss_id = crypt.encrypt_and_sign(self.ss_id) if ss_id_changed?
  end

  def self.decrypt_user_credentials(userID, columnName)
    key = YAML::load_file(Rails.root+'plugins/redmine_wktime/config/config.yml')
    crypt = ActiveSupport::MessageEncryptor.new(key['encryption_key'])
    usrdata = self.where(user_id: userID).first
    decryptVal = crypt.decrypt_and_verify(usrdata["#{columnName}"]) if usrdata["#{columnName}"].present?
    decryptVal
  end

  def show_account
    WkUser.show_data(self.user_id, 'account_number')
  end

  def show_ss
    WkUser.show_data(self.user_id, 'ss_id')
  end

  def show_tax
    WkUser.show_data(self.user_id, 'tax_id')
  end

  def self.show_data(userID, columnName)
    decryptVal = decrypt_user_credentials(userID, columnName)
    if decryptVal.present? && decryptVal.length > 5
      randomTxtLength = decryptVal.length - 4
      randomText = "x" * randomTxtLength
      decryptVal = randomText+decryptVal.last(4)
    end
    decryptVal
  end

  def self.updateWkUser(userID, columnName, value)
    usrdata = self.where(user_id: userID).first
    usrdata["#{columnName}"] = value
    usrdata.save
  end
end
