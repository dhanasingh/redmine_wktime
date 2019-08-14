class ChangeWkInventoryItem < ActiveRecord::Migration[4.2]
    def change
        add_reference :wk_inventory_items, :project, index: true

        reversible do |dir|
			dir.up do
                change_column :wk_permissions, :modules, :string

				execute <<-SQL
					INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (15, 'VIEW REPORT', 'V_REPORT', 'Report', current_timestamp, current_timestamp);
				SQL

				execute <<-SQL
				    UPDATE wk_permissions set modules = 'Inventory' where name in ('VIEW INVENTORY', 'DELETE INVENTORY');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'Shift Scheduling' where name in ('SCHEDULES SHIFT', 'EDIT SHIFT SCHEDULES');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'Survey' where name in ('EDIT SURVEY');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'Billing' where name in ('MANAGE BILLING');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'Accounting' where name in ('BASIC ACCOUNTING PRIVILEGE', 'ADMIN ACCOUNTING PRIVILEGE');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'Purchase' where name in ('BASIC PURCHASING PRIVILEGE', 'ADMIN PURCHASING PRIVILEGE');
                SQL
            end

            dir.down do
                
				execute <<-SQL
					DELETE FROM wk_group_permissions WHERE permission_id IN (SELECT ID FROM wk_permissions WHERE short_name IN ('V_REPORT'))
				SQL
			
				execute <<-SQL
					DELETE from wk_permissions where short_name = 'V_REPORT';
				SQL

				execute <<-SQL
				    UPDATE wk_permissions set modules = 'IN' where name in ('VIEW INVENTORY', 'DELETE INVENTORY');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'SC' where name in ('SCHEDULES SHIFT', 'EDIT SHIFT SCHEDULES');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'SU' where name in ('EDIT SURVEY');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'BILL' where name in ('MANAGE BILLING');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'ACC' where name in ('BASIC ACCOUNTING PRIVILEGE', 'ADMIN ACCOUNTING PRIVILEGE');
                SQL
                
                execute <<-SQL
                    UPDATE wk_permissions set modules = 'PUR' where name in ('BASIC PURCHASING PRIVILEGE', 'ADMIN PURCHASING PRIVILEGE');
                SQL
                
				change_column :wk_permissions, :modules, :string, :limit => 5
			end 
		end
    end
end