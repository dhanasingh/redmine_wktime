class WkTax < ActiveRecord::Base
  unloadable
  has_many :wk_project_taxes, foreign_key: "tax_id", class_name: "WkAccProjectTax", :dependent => :destroy
end
