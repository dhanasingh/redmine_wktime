class CreateWkUserNotification < ActiveRecord::Migration[5.2]
  def change

    create_table :wk_user_notifications do |t|
      t.references :user, null: false, index: true
      t.references :notify, class: "WkNotification", null: false
      t.boolean :seen
      t.datetime :seen_on, :null => false
      t.references :source, polymorphic: true, index: true
      t.timestamps null: false
    end
    
    add_column :wk_notifications, :email, :boolean
  end
end