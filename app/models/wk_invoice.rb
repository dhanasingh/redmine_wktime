class WkInvoice < ActiveRecord::Base
  unloadable
  belongs_to :account, :class_name => 'WkAccount'
  belongs_to :modifier , :class_name => 'User'
  has_many :wk_invoice_items, foreign_key: "invoice_id", class_name: "WkInvoiceItem", :dependent => :destroy
  
  attr_protected :modifier_id
  
  validates_presence_of :account_id
end
