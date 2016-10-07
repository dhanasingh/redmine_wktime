class WkInvoiceItem < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes
  
  belongs_to :account_project
end
