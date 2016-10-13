class WkInvoiceItem < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  belongs_to :invoice, :class_name => 'WkInvoice'
  belongs_to :modifier, :class_name => 'User'
  
  attr_protected :modifier_id
  
  validates_presence_of :invoice_id
  validates_numericality_of :amount, :allow_nil => true, :message => :invalid
  validates_numericality_of :quantity, :allow_nil => true, :message => :invalid
  validates_numericality_of :rate, :allow_nil => true, :message => :invalid
end
