class WkAccount < ActiveRecord::Base
  unloadable
  belongs_to :address, :class_name => 'WkAddress'
end
