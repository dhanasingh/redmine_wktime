class AddClockAction < ActiveRecord::Migration[5.2]
  def change
    add_column :wk_spent_fors, :clock_action, :string
    remove_column :wk_spent_fors, :start_on, :datetime
  end
end