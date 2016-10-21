class WkAccountProject < ActiveRecord::Base
  unloadable
  belongs_to :project
  belongs_to :account, :class_name => 'WkAccount'
  
  has_many :wk_billing_schedules, foreign_key: "account_project_id", class_name: "WkBillingSchedule", :dependent => :destroy
  has_many :wk_acc_project_taxes, foreign_key: "account_project_id", class_name: "WkAccProjectTax", :dependent => :destroy
end
