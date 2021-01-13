class CreateWkUserNotification < ActiveRecord::Migration[5.2]
  def change
    create_table :wk_user_notifications do |t|
      t.references :user, null: false, index: true
      t.references :notify, class: "WkNotification", null: false
      t.boolean :seen, default: false, null: false
      t.datetime :seen_on
      t.references :source, polymorphic: true, index: true
      t.timestamps null: false
    end

    add_column :wk_notifications, :email, :boolean, default: false, null: false
    add_column :wk_surveys, :save_allowed, :boolean
    add_index :wk_notifications, :name
  end
end