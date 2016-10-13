class WkProjectTax < ActiveRecord::Base
  unloadable
  belongs_to :project
end
