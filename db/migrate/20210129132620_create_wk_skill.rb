class CreateWkSkill < ActiveRecord::Migration[5.2]
  def change
    add_column :wk_notifications, :active, :boolean, default: true, index: true
    add_reference :wk_expense_entries, :payroll, :class => "wk_salaries", :null => true
    add_reference :wk_users, :source, polymorphic: true

    create_table :wk_skills do |t|
      t.references :user, null: false, index: true
      t.references :skill_set, class: "WkCrmEnumeration", null: false, index: true
      t.integer :rating
      t.integer :last_used, limit: 4
      t.decimal :experience, precision: 5, scale: 2
      t.timestamps null: false
    end

    reversible do |dir|
      dir.up do
        WkExpenseEntry.update_all('payroll_id = 0')
        WkNotification.update_all(active: true)
        WkPermission.where(short_name: "A_PAYRL").first&.update!(modules: "HR")
        WkPermission.create([
          {id: 19, name: "ADMIN SKILL SET PRIVILEGE", short_name: "A_SKILL", modules: "HR", created_at: 'current_timestamp', updated_at: 'current_timestamp'},
          {id: 20, name: "ADMIN REFERRAL PRIVILEGE", short_name: "A_REFERRAL", modules: "HR", created_at: 'current_timestamp', updated_at: 'current_timestamp'}
          ])
       end

       dir.down do
        WkPermission.where(short_name: "A_PAYRL").first&.update!(modules: "PAYROLL")
        ["A_SKILL", "A_REFERRAL"].each{|p| WkPermission.where(short_name: p).destroy_all}
      end
    end
  end
end