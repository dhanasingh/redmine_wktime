class WkInvoice < ActiveRecord::Base
  unloadable
  belongs_to :account, :class_name => 'WkAccount'
  belongs_to :modifier , :class_name => 'User'
  belongs_to :gl_transaction , :class_name => 'WkGlTransaction', :dependent => :destroy
  has_many :invoice_items, foreign_key: "invoice_id", class_name: "WkInvoiceItem", :dependent => :destroy
  has_many :projects, through: :invoice_items
  
  attr_protected :modifier_id
  
  validates_presence_of :account_id
  
end
