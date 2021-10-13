class CreateWkDeliveryItems < ActiveRecord::Migration[5.2]
  def change
    create_table :wk_delivery_items do |t|
			t.references :shipment, class: "wk_shipments", null: true, index: true
			t.references :location, class: "wk_locations", null: true, index: true
			t.references :inventory_item, class: "wk_inventory_items", null: false, index: true
			t.float :org_selling_price
			t.column :org_currency, :string, limit: 5
			t.float :selling_price
			t.column :currency, :string, limit: 5, default: '$'
			t.float :total_quantity
			t.string :serial_number
			t.string :running_sn
			t.string :notes
			t.references :project, null: true
			t.timestamps null: false
    end
    add_column :wk_statuses, :longitude, :decimal, precision: 30, scale: 20
    add_column :wk_statuses, :latitude, :decimal, precision: 30, scale: 20
    add_column :wk_crm_activities, :rating, :string
    add_column :wk_account_projects, :include_expense, :boolean, default: false
    add_column :wk_users, :retirement_account, :string
    add_reference :wk_shipments, :invoice, class: "wk_invoices", null: true

		reversible do |dir|
      dir.up do
				wksetting = WkSetting.new name: "leave_settings", value: Setting.plugin_redmine_wktime['wktime_leave']
				wksetting.save
        change_column :wk_crm_activities, :description, :text
      end
      dir.down do
        value = WkSetting.where(name: "leave_settings").first&.value
        if value.present?
          config = Setting.plugin_redmine_wktime
          config[:wktime_leave] = JSON.parse(value)
          Setting.send "plugin_redmine_wktime=", config
        end
        WkSetting.where(name: "leave_settings").destroy_all
        WkShipment.where(shipment_type: "O").destroy_all
      end
    end
  end
end
