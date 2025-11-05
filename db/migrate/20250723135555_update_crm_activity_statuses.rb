class UpdateCrmActivityStatuses < ActiveRecord::Migration[6.1]
  def up
    execute "UPDATE wk_crm_activities SET status = 'NS' WHERE status = 'P'"
    execute "UPDATE wk_crm_activities SET status = 'C' WHERE status = 'H'"
    execute "UPDATE wk_crm_activities SET status = 'D' WHERE status = 'NH'"
  end

  def down
    execute "UPDATE wk_crm_activities SET status = 'P' WHERE status = 'NS' AND activity_type IN ('C', 'M')"
    execute "UPDATE wk_crm_activities SET status = 'H' WHERE status = 'C' AND activity_type IN ('C', 'M')"
    execute "UPDATE wk_crm_activities SET status = 'NH' WHERE status = 'D' AND activity_type IN ('C', 'M')"
  end
end