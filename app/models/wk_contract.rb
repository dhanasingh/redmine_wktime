class WkContract < ActiveRecord::Base
  unloadable
  belongs_to :project
  belongs_to :account, :class_name => 'WkAccount'
end
