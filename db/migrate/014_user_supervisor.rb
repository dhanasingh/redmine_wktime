class UserSupervisor < ActiveRecord::Migration[4.2]
  def self.up   
	add_column :users, :parent_id, :integer
    add_column :users, :lft, :integer
    add_column :users, :rgt, :integer
	
	User.rebuild_tree!
  end

  def self.down   
	remove_column :users, :parent_id
    remove_column :users, :lft
    remove_column :users, :rgt
  end
end
