class CreateWkIncomeTax < ActiveRecord::Migration[4.2]
  def change

    create_table :wk_settings do |t|
      t.string :name, null: false
      t.text :value
      t.timestamps null: false
    end

    create_table :wk_income_taxes do |t|
      t.references :user, null: false, index: true
      t.string :name, null: false
      t.text :value
      t.timestamps null: false
    end
  
    rename_table :wk_component_conditions, :wk_sal_comp_conditions
    rename_column :wk_sal_comp_conditions, :left_hand_side, :lhs
    rename_column :wk_sal_comp_conditions, :right_hand_side, :rhs
    add_column :wk_sal_comp_conditions, :rhs2, :decimal, precision: 16, scale: 4

    create_table :wk_sal_comp_dependents do |t|
      t.references :salary_component, class: "WkSalaryComponents", null: false, index: true
      t.references :dependent, class: "WkSalaryComponents", index: true
      t.decimal :factor, precision: 16, scale: 4
      t.string :factor_op, null: false, limit: 5
      t.timestamps null: false
    end

    add_reference :wk_sal_comp_conditions, :sal_comp_dep, class: "WkSalCompConditions", index: true
    remove_column :wk_sal_comp_conditions, :salary_component_id, :integer
    remove_column :wk_salary_components, :factor, :float
    remove_column :wk_salary_components, :dependent_id, :integer

    add_column :wk_survey_responses, :group_name, :string, index: true
  end
end