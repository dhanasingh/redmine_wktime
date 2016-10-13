class WkBillingSchedule < ActiveRecord::Base
  unloadable
  
  belongs_to :account_project, :class_name => 'WkAccountProject', :foreign_key => 'account_project_id'
  belongs_to :invoice, :class_name => 'WkInvoice'
  
  validates_numericality_of :amount, :allow_nil => true, :message => :invalid
end
