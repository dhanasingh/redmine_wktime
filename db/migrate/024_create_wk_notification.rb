class CreateWkNotification < ActiveRecord::Migration[5.2]
  def change

    create_table :wk_notifications do |t|
			t.string :name
			t.string :modules
			t.timestamps null: false
    end
    
    add_column :wk_leave_reqs, :reviewer_comment, :text
    add_column :wk_asset_properties, :longitude, :decimal, precision: 30, scale: 20
    add_column :wk_asset_properties, :latitude, :decimal, precision: 30, scale: 20
    add_reference :wk_locations, :attachment, class: "Attachment", index: true
    remove_column :wk_locations, :longitude, :decimal
    remove_column :wk_locations, :latitude, :decimal
    add_column :wk_crm_activities, :longitude, :decimal, precision: 30, scale: 20
    add_column :wk_crm_activities, :latitude, :decimal, precision: 30, scale: 20
  end
end