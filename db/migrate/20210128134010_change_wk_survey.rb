class ChangeWkSurvey < ActiveRecord::Migration[5.2]
  def change
    add_column :wk_surveys, :hide_response, :boolean
    create_table :wk_candidates do |t|
      t.references :lead, class: "WkLead", null: false, index: true
      t.string :college
      t.string :degree
      t.integer :pass_out
      t.timestamps null: false
    end
  end
end