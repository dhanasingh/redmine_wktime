class WkGlTransactionDetail < ActiveRecord::Base
  unloadable
  belongs_to :ledger, :class_name => 'WkLedger'
  belongs_to :wkgltransaction, :class_name => 'WkGlTransaction', :foreign_key => 'gl_transaction_id'
end
