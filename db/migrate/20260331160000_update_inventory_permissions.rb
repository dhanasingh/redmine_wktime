class UpdateInventoryPermissions < ActiveRecord::Migration[7.2]

  def up
    # ---- Survey ----
    add_reference :wk_survey_choices, :follow_up_question, polymorphic: true
    add_column :wk_survey_questions, :parent_id, :integer
    add_column :wk_survey_questions, :lft, :integer
    add_column :wk_survey_questions, :rgt, :integer
    add_index :wk_survey_questions, :parent_id
    add_column :wk_survey_que_groups, :parent_id, :integer
    add_column :wk_survey_que_groups, :lft, :integer
    add_column :wk_survey_que_groups, :rgt, :integer
    add_index :wk_survey_que_groups, :parent_id

    # ---- Permissions ----
    add_column :wk_permissions, :plugin, :string, limit: 5, default: 'wk'
    change_column_null :wk_permissions, :plugin, false

    execute "UPDATE wk_permissions SET modules = 'Scheduling' WHERE short_name IN ('S_SHIFT','E_SHIFT')"
    execute "UPDATE wk_permissions SET name = 'BASIC INVENTORY PRIVILEGE', short_name = 'B_INV_PRVLG', modules = 'Inventory' WHERE short_name = 'V_INV'"
    execute "UPDATE wk_permissions SET name = 'ADMIN INVENTORY PRIVILEGE', short_name = 'A_INV_PRVLG', modules = 'Inventory' WHERE short_name = 'D_INV'"
    execute "UPDATE wk_leads SET status = 'L' WHERE status = 'D'"
  end


  def down
    execute "UPDATE wk_permissions SET modules = 'Shift Scheduling' WHERE short_name IN ('S_SHIFT','E_SHIFT')"
    execute "UPDATE wk_permissions SET name = 'VIEW INVENTORY', short_name = 'V_INV', modules = 'Inventory' WHERE short_name = 'B_INV_PRVLG'"
    execute "UPDATE wk_permissions SET name = 'DELETE INVENTORY', short_name = 'D_INV', modules = 'Inventory' WHERE short_name = 'A_INV_PRVLG'"
    execute "UPDATE wk_leads SET status = 'D' WHERE status = 'L'"

    remove_column :wk_permissions, :plugin
    remove_reference :wk_survey_choices, :follow_up_question, polymorphic: true
    remove_column :wk_survey_questions, :parent_id
    remove_column :wk_survey_questions, :lft
    remove_column :wk_survey_questions, :rgt
    remove_column :wk_survey_que_groups, :parent_id
    remove_column :wk_survey_que_groups, :lft
    remove_column :wk_survey_que_groups, :rgt
  end

end