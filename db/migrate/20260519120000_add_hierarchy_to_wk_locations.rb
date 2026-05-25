class AddHierarchyToWkLocations < ActiveRecord::Migration[7.2]
  def up
    add_column :wk_locations, :parent_id, :integer, null: true
    add_column :wk_locations, :root_id,   :integer, null: true
    add_column :wk_locations, :lft,       :integer, null: true
    add_column :wk_locations, :rgt,       :integer, null: true
    add_index  :wk_locations, :parent_id
    add_index  :wk_locations, [:root_id, :lft, :rgt]

    WkLocation.unscoped.update_all("root_id = id, lft = 1, rgt = 2")
  end

  def down
    remove_index  :wk_locations, [:root_id, :lft, :rgt]
    remove_index  :wk_locations, :parent_id
    remove_column :wk_locations, :rgt
    remove_column :wk_locations, :lft
    remove_column :wk_locations, :root_id
    remove_column :wk_locations, :parent_id
  end
end
