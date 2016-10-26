class WkAccount < ActiveRecord::Base
  unloadable
  belongs_to :address, :class_name => 'WkAddress'
  has_many :wk_account_projects, foreign_key: "account_id", class_name: "WkAccountProject", :dependent => :destroy
end
