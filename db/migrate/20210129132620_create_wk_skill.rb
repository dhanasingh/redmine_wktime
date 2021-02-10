class CreateWkSkill < ActiveRecord::Migration[5.2]
  def change
    create_table :wk_skills do |t|
      t.references :user, null: false, index: true
      t.references :skill_set, class: "WkCrmEnumeration", null: false
      t.decimal :rating, precision: 5, scale: 2
      t.integer :last_used, limit: 4
      t.decimal :experience, precision: 5, scale: 2
      t.timestamps null: false
    end

    reversible do |dir|
      dir.up do
				execute <<-SQL
          UPDATE wk_permissions set modules = 'HR' where name in ('ADMIN PAYROLL PRIVILEGE');
        SQL

        execute <<-SQL
          INSERT INTO wk_permissions(id, name, short_name, modules, created_at, updated_at) VALUES (19, 'ADMIN SKILL SET', 'A_SKILL', 'HR', current_timestamp, current_timestamp);
        SQL
      end

      dir.down do
				execute <<-SQL
          UPDATE wk_permissions set modules = 'PAYROLL' where name in ('ADMIN PAYROLL PRIVILEGE');
        SQL

        execute <<-SQL
          DELETE FROM wk_group_permissions WHERE permission_id IN (SELECT ID FROM wk_permissions WHERE short_name IN ('A_SKILL'))
        SQL

        execute <<-SQL
          DELETE from wk_permissions where short_name = 'A_SKILL';
        SQL
      end
    end
  end
end