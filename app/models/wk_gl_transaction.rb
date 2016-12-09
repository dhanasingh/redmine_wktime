class WkGlTransaction < ActiveRecord::Base
  unloadable
  has_many :transaction_details, foreign_key: "gl_transaction_id", class_name: "WkGlTransactionDetail", :dependent => :destroy
  has_one :invoice, foreign_key: "gl_transaction_id", class_name: "WkInvoice"
  validates_presence_of :trans_date
end
