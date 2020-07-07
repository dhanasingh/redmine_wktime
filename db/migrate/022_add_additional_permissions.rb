class AddAdditionalPermissions < ActiveRecord::Migration[5.2]
  def change
    reversible do |dir|
      dir.up do
        execute <<-SQL
          INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (16, 'ADMIN ATTENDANCE PRIVILEGE', 'A_ATTEND', 'ATTENDANCE', current_timestamp, current_timestamp);
        SQL

        execute <<-SQL
          INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (17, 'RECEIVE LEAVE NOTIFICATION', 'R_LEAVE', 'ATTENDANCE', current_timestamp, current_timestamp);
        SQL

        execute <<-SQL
          INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (18, 'ADMIN PAYROLL PRIVILEGE', 'A_PAYRL', 'PAYROLL', current_timestamp, current_timestamp);
        SQL
      end

      dir.down do
        execute <<-SQL
          DELETE FROM wk_group_permissions WHERE permission_id IN (SELECT ID FROM wk_permissions WHERE short_name IN ('A_ATTEND'))
        SQL

        execute <<-SQL
          DELETE from wk_permissions where short_name = 'A_ATTEND';
        SQL

        execute <<-SQL
          DELETE FROM wk_group_permissions WHERE permission_id IN (SELECT ID FROM wk_permissions WHERE short_name IN ('R_LEAVE'))
        SQL

        execute <<-SQL
          DELETE from wk_permissions where short_name = 'R_LEAVE';
        SQL

        execute <<-SQL
          DELETE FROM wk_group_permissions WHERE permission_id IN (SELECT ID FROM wk_permissions WHERE short_name IN ('A_PAYRL'))
        SQL

        execute <<-SQL
          DELETE from wk_permissions where short_name = 'A_PAYRL';
        SQL
      end
    end

    add_column :wk_spent_fors, :start_on, :datetime
    add_column :wk_spent_fors, :end_on, :datetime
    add_column :wk_spent_fors, :s_longitude, :decimal, precision: 30, scale: 20
    add_column :wk_spent_fors, :s_latitude, :decimal, precision: 30, scale: 20
    add_column :wk_spent_fors, :e_longitude, :decimal, precision: 30, scale: 20
    add_column :wk_spent_fors, :e_latitude, :decimal, precision: 30, scale: 20
    add_column :wk_attendances, :s_longitude, :decimal, precision: 30, scale: 20
    add_column :wk_attendances, :s_latitude, :decimal, precision: 30, scale: 20
    add_column :wk_attendances, :e_longitude, :decimal, precision: 30, scale: 20
    add_column :wk_attendances, :e_latitude, :decimal, precision: 30, scale: 20
    add_column :wk_addresses, :longitude, :decimal, precision: 30, scale: 20
    add_column :wk_addresses, :latitude, :decimal, precision: 30, scale: 20
    add_column :wk_locations, :longitude, :decimal, precision: 30, scale: 20
    add_column :wk_locations, :latitude, :decimal, precision: 30, scale: 20
    add_reference :wk_asset_properties, :gl_transaction, :class => "wk_gl_transactions", :null => true, index: true
  end
end