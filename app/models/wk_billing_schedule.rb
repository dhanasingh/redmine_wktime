class WkBillingSchedule < ActiveRecord::Base
  unloadable
  
  belongs_to :account_project, :class_name => 'WkAccountProject', :foreign_key => 'account_project_id'
  belongs_to :invoice, :class_name => 'WkInvoice'
  
  validates_presence_of :milestone, :bill_date, :currency
  validates_numericality_of :amount, :allow_nil => false, :message => :invalid
end
