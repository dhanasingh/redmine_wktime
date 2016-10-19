class WkProjectTax < ActiveRecord::Base
  unloadable
  belongs_to :project
  belongs_to :tax, :class_name => 'WkTax'
  #has_many :projects
end
