#!/bin/env ruby
# encoding: utf-8
class CreateWkCrm < ActiveRecord::Migration[4.2]
	class WkCrmEnumeration < ActiveRecord::Base
		# attr_protected :id
	end
	
    def change
		
		create_table :wk_crm_enumerations do |t|
		  t.string :name
		  t.string :position
		  t.boolean :is_default
		  t.boolean :active
		  t.string :enum_type, :null => false
		  t.timestamps null: false
		end
  
		create_table :wk_crm_activities do |t|
		  t.string :name
		  t.string :status, :null => false, :limit => 3
		  t.string :description	
		  t.datetime :start_date
		  t.datetime :end_date
		  t.datetime :status_update_on
		  t.string :activity_type, :null => false, :limit => 3
		  t.string :direction, :limit => 3
		  t.integer :duration
		  t.string :location
		  t.references :parent, polymorphic: true, index: true
		  t.references :assigned_user, :class => "User", :null => true
		  t.references :created_by_user, :class => "User"
		  t.references :updated_by_user, :class => "User"
		  t.timestamps null: false
		end
		
		create_table :wk_crm_contacts do |t|
		  t.string :first_name
		  t.string :last_name
		  t.references :address, :class => "wk_addresses", :null => true
		  t.string :title
		  t.string :department
		  t.references :assigned_user, :class => "User", :null => true
		  t.string :salutation
		  t.string :description
		  #t.references :parent, polymorphic: true, index: true
		  t.references :account, :class => "wk_accounts", :null => true
		  t.references :created_by_user, :class => "User"
		  t.references :updated_by_user, :class => "User"
		  t.timestamps null: false
		end
		add_index  :wk_crm_contacts, :address_id
		
		create_table :wk_leads do |t|
		  t.string :status, :null => false, :limit => 3
		  t.datetime :status_update_on
		  t.decimal :opportunity_amount
		  t.references :lead_source, :class => "wk_crm_enumerations"
		  t.string :referred_by
		  t.references :account, :class => "wk_accounts", :null => true
		  t.references :contact, :class => "wk_crm_contacts", :null => true
		  t.references :created_by_user, :class => "User"
		  t.references :updated_by_user, :class => "User"
		  t.timestamps null: false
		end
		
		create_table :wk_opportunities do |t|
		  t.string :name
		  t.column :currency, :string, :limit => 5, :default => '$'
		  t.datetime :close_date, :null => false
		  t.decimal :amount, :null => false
		  t.references :parent, polymorphic: true, index: true
		  t.references :assigned_user, :class => "User", :null => true
		  t.references :opportunity_type, :class => "wk_crm_enumerations", :null => true
		  t.references :sales_stage, :class => "wk_crm_enumerations", :null => false
		  t.references :lead_source, :class => "wk_crm_enumerations"
		  t.string :probability 
		  t.string :next_step
		  t.string :description		  
		  t.references :created_by_user, :class => "User"
		  t.references :updated_by_user, :class => "User"
		  t.timestamps null: false
		end		
		
		#add column in wk_address table
		add_column :wk_addresses, :department, :string
		add_column :wk_addresses, :website, :string
		
		#add column in wk_accounts table
		add_reference :wk_accounts, :activity, :class => "wk_crm_activites", :null => true, index: true
		add_column :wk_accounts, :account_category, :string
		add_column :wk_accounts, :industry, :string
		add_column :wk_accounts, :annual_revenue, :float
		add_column :wk_accounts, :description, :string
		add_reference :wk_accounts, :assigned_user, :class => "User"
		add_reference :wk_accounts, :created_by_user, :class => "User"
		add_reference :wk_accounts, :updated_by_user, :class => "User"
		
		enumValues = Hash.new
		enumValues["LS"] = ['Cold Call', 'Existing Customer', 'Self Generated', 'Employee', 'Partner', 'Public Relations', 'Direct Mail', 'Conference', 'Trade Show', 'Web Site', 'Word Of Mouth', 'Email', 'Other']
		enumValues["SS"] = ['Prospecting', 'Qualification', 'Needs Analysis', 'Value Proposition', 'Id.Decision Makers', 'Perception Analysis', 'Proposal/Price Quote', 'Negotiation/Review', 'Closed Won', 'Closed Lost']
		enumValues["OT"] = ['New Business', 'Existing Business']
		enumValues["AC"] = ['Analyst', 'Competitor', 'Customer', 'Integrator', 'Investor', 'Partner', 'Press', 'Prospect', 'Reseller', 'Other']
		enumValues.each do |enumType, values|
			values.each_with_index do |val, index|
				WkCrmEnumeration.create :name => val, :position => index+1, :is_default => index == 0, :active => true, :enum_type => enumType
			end
		end
  end
end
