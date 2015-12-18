class CreateWkAttendances < ActiveRecord::Migration
  def change
    create_table :wk_attendances do |t|
		t.references :user, :null => false
		t.datetime :start_time
		t.datetime :end_time
		t.timestamps null: false
    end
	add_index  :wk_attendances, :user_id
	
	create_table :wk_user_leaves do |t|
      t.references :user, :null => false
	  t.references :issue, :null => false
	  t.float :no_of_days
	  t.date :accrual_on, :null => false
	  t.timestamps null: false
    end
	add_index  :wk_user_leaves, :user_id
  end
end

