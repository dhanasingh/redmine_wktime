class SettingsPermission< ActiveRecord::Migration[4.2]
  def change
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
  end
end