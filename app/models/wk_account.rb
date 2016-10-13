class WkAccount < ActiveRecord::Base
  unloadable
  has_one :address, :class_name => 'WkAddress'
end
