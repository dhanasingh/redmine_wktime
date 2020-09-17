class AddAssetsMap < ActiveRecord::Migration[5.2]
  def change
    add_column :wk_leave_reqs, :reviewer_comment, :text
    add_column :wk_asset_properties, :longitude, :decimal, precision: 30, scale: 20
    add_column :wk_asset_properties, :latitude, :decimal, precision: 30, scale: 20
  end
end