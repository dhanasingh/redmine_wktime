class WkLedger < ActiveRecord::Base
  unloadable
  has_many :transaction_details, foreign_key: "ledger_id", class_name: "WkTransactionDetail"
end
