class CreateWkSkill < ActiveRecord::Migration[5.2]
  def change
    create_table :wk_skills do |t|
      t.references :user, null: false, index: true
      t.references :skill_set, class: "WkCrmEnumeration", null: false
      t.decimal :rating, null: false, precision: 5, scale: 2
      t.integer :last_used, limit: 4
      t.decimal :experience, precision: 5, scale: 2
      t.timestamps null: false
    end
  end
end