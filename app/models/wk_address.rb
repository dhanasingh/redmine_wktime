class WkAddress < ActiveRecord::Base
  unloadable
  has_many :wk_accounts, foreign_key: "address_id", class_name: "WkAccount"
  validates_presence_of :address1, :work_phone, :fax, :city, :state, :country, :pin
end
