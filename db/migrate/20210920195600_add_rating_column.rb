class AddRatingColumn < ActiveRecord::Migration[5.2]
  def change
    add_column :wk_crm_activities, :rating, :string
  end
end
