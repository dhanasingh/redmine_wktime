class WkTransactionDetail < ActiveRecord::Base
  unloadable
  belongs_to :ledger, :class_name => 'WkLedger'
  belongs_to :wktransaction, :class_name => 'WkTransaction', :foreign_key => 'transaction_id'
end
