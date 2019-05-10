class SettingsPermission< ActiveRecord::Migration[4.2]
	def change

		add_column :wk_locations, :is_main, :boolean
	
		reversible do |dir|
		
			dir.up do
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (6, 'BASIC CRM PRIVILEGE', 'B_CRM_PRVLG', 'CRM', current_timestamp, current_timestamp);
				SQL
				
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (7, 'ADMIN CRM PRIVILEGE', 'A_CRM_PRVLG', 'CRM', current_timestamp, current_timestamp);
				SQL
				
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (8, 'MANAGE BILLING', 'M_BILL', 'BILL', current_timestamp, current_timestamp);
				SQL
				
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (9, 'BASIC ACCOUNTING PRIVILEGE', 'B_ACC_PRVLG', 'ACC', current_timestamp, current_timestamp);
				SQL
				
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (10, 'ADMIN ACCOUNTING PRIVILEGE', 'A_ACC_PRVLG', 'ACC', current_timestamp, current_timestamp);
				SQL
				
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (11, 'BASIC PURCHASING PRIVILEGE', 'B_PUR_PRVLG', 'PUR', current_timestamp, current_timestamp);
				SQL
				
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (12, 'ADMIN PURCHASING PRIVILEGE', 'A_PUR_PRVLG', 'PUR', current_timestamp, current_timestamp);
				SQL
				
				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (13, 'ADMIN ERPMINE', 'ADM_ERP', '', current_timestamp, current_timestamp);
				SQL
			end
			
			dir.down do 			
				execute <<-SQL
					DELETE FROM wk_group_permissions WHERE permission_id IN (SELECT ID FROM wk_permissions WHERE short_name IN ('B_CRM_PRVLG', 'A_CRM_PRVLG', 'M_BILL', 'B_ACC_PRVLG', 'A_ACC_PRVLG', 'B_PUR_PRVLG', 'A_PUR_PRVLG', 'ADM_ERP'))
				SQL
			
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'B_CRM_PRVLG';
				SQL
				
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'A_CRM_PRVLG';
				SQL
				
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'M_BILL';
				SQL
				
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'B_ACC_PRVLG';
				SQL
				
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'A_ACC_PRVLG';
				SQL
				
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'B_PUR_PRVLG';
				SQL
				
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'A_PUR_PRVLG';
				SQL
					
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'ADM_ERP';
				SQL
			end 
		end

		change_table :wk_survey_responses do |t|
			t.references :survey_for, polymorphic: true, index: true
		end

		change_table :wk_surveys do |t|
		  t.rename :recur_after, :recur_every
		end

		create_table :wk_projects do |t|
			t.references :project, :null => false
			t.float :billing_rate
			t.column :billing_currency, :string, :limit => 5, :default => '$'
			t.boolean :is_issueSurvey_allowed, :default => false
			t.timestamps null: false
		end

  end
end