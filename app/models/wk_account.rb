class WkAccount < ActiveRecord::Base
  unloadable
  belongs_to :address, :class_name => 'WkAddress'
  has_many :wk_account_projects, foreign_key: "account_id", class_name: "WkAccountProject", :dependent => :destroy
  has_many :invoices, foreign_key: "account_id", class_name: "WkInvoice"
  has_many :invoice_items, through: :invoices
  has_many :projects, through: :wk_account_projects
  has_many :contracts, foreign_key: "account_id", class_name: "WkContract", :dependent => :destroy
  validates_presence_of :name
  
  # Returns account's contracts for the given project
  # or nil if the account do not have contract
  def contract(project)
		contract = contracts.where(:project_id => project.id).first
		contract = contracts[0] if contract.blank?
		contract
  end
end
