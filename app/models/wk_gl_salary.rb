class WkGlSalary < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :gl_transaction, foreign_key: "gl_transaction_id", class_name: "WkGlTransaction", :dependent => :destroy
end