class WkTax < ActiveRecord::Base
  unloadable
  has_many :wk_project_taxes, :dependent => :destroy
end
