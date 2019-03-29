class ResizeDescriptionOfCrmActivities < ActiveRecord::Migration
  def up
    change_column :wk_crm_activities, :description, :text
  end
  def down
    change_column :wk_crm_activities, :description, :string
  end
end
