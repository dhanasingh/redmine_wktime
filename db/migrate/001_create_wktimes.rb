class CreateWktimes < ActiveRecord::Migration
  def change
    create_table :wktimes do |t|
	  t.references :user, :null => false
      t.date :begin_date, :null => false
      t.float :hours, :null => false
      t.string :status, :null => false, :limit => 2, :default => 'n'
      t.date :submitted_on
      t.date :statusupdate_on
	  t.references :submitter, :class => "User", :null => true
	  t.references :statusupdater, :class => "User"
	  t.string :notes
	  t.timestamps null: false
    end
	add_index  :wktimes, :user_id
	add_index  :wktimes, :begin_date
  end
end
