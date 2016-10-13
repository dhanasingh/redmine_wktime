class WkAccountProject < ActiveRecord::Base
  unloadable
  belongs_to :project
  belongs_to :account, :class_name => 'WkAccount'
  
  has_many :wk_billing_schedules, :dependent => :destroy
end
