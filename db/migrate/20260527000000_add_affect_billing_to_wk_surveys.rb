class AddAffectBillingToWkSurveys < ActiveRecord::Migration[6.1]
  def change
    add_column :wk_surveys, :affect_billing, :boolean, default: false
    add_column :wk_issues, :min_points, :float, null: true
    add_column :wk_issues, :max_points, :float, null: true
  end
end
