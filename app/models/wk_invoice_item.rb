class WkInvoiceItem < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  belongs_to :invoice, :class_name => 'WkInvoice'
  belongs_to :modifier, :class_name => 'User'
  belongs_to :project
  
  attr_protected :modifier_id
  
  validates_presence_of :invoice_id
  validates_numericality_of :amount, :message => :invalid
  validates_numericality_of :quantity, :message => :invalid
  validates_numericality_of :rate, :message => :invalid
end
