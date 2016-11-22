class WkTransactionDetail < ActiveRecord::Base
  unloadable
  belongs_to :ledger, :class_name => 'WkLedger'
  belongs_to :transaction, :class_name => 'WkTransaction'
end
