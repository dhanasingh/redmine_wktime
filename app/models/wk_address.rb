class WkAddress < ActiveRecord::Base
  unloadable
  has_many :wk_accounts, foreign_key: "address_id", class_name: "WkAccount"
  validates_presence_of :address1, :work_phone, :fax, :city, :state, :country
  validates_numericality_of :pin, :only_integer => true, :greater_than_or_equal_to => 0, :message => :invalid
end
