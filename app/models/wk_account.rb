class WkAccount < ActiveRecord::Base
  unloadable
  belongs_to :address, :class_name => 'WkAddress'
  has_many :wk_account_projects, foreign_key: "account_id", class_name: "WkAccountProject", :dependent => :destroy
  has_many :invoices, foreign_key: "account_id", class_name: "WkInvoice"
  has_many :invoice_items, through: :invoices
  has_many :projects, through: :wk_account_projects
end
