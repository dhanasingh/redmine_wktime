class CreateWkLeaveRequest< ActiveRecord::Migration[4.2]
  def change
    create_table :wk_leave_reqs do |t|
      t.references :user, null: false, index: true
	    t.references :leave_type, null: false, class: "Issue", index: true
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.text :leave_reasons
      t.timestamps null: false
    end

    create_table :wk_component_conditions do |t|
      t.references :salary_component, :class => "wk_salary_components", :null => false, index: true
      t.integer :left_hand_side, :null => false
      t.string :operators, :null => false, :limit => 5
      t.float :right_hand_side, :null => false
      t.timestamps :null => false
    end

    add_column :wk_survey_responses, :group_date, :datetime
    add_column :wk_survey_questions, :not_in_report, :boolean, :default => false
    add_reference :wk_statuses, :status_by, index: true, class: "User"
  end
end