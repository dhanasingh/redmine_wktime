class CreateWkAttendances < ActiveRecord::Migration
  def change
    create_table :wk_attendances do |t|
		t.references :user, :null => false
		t.time :start_time
		t.time :end_time
		t.date :week_date
		t.timestamps null: false
    end
	add_index  :wk_attendances, :user_id
  end
end
