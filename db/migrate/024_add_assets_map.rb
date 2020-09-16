class AddAssetsMap < ActiveRecord::Migration[5.2]
  def change
    add_column :wk_leave_reqs, :reviewer_comment, :text
    add_column :wk_inventory_items, :longitude, :decimal, precision: 30, scale: 20
    add_column :wk_inventory_items, :latitude, :decimal, precision: 30, scale: 20
  end
end