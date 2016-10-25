class WkAddress < ActiveRecord::Base
  unloadable
  has_many :wk_accounts, foreign_key: "address_id", class_name: "WkAccount"
end
