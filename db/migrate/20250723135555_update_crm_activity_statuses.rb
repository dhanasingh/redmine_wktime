class UpdateCrmActivityStatuses < ActiveRecord::Migration[7.2]
  def up
    execute <<-SQL
      UPDATE wk_crm_activities SET status = 'NS' WHERE status = 'P';
      UPDATE wk_crm_activities SET status = 'C'  WHERE status = 'H';
      UPDATE wk_crm_activities SET status = 'D'  WHERE status = 'NH';
    SQL
  end

  def down
    execute <<-SQL
      UPDATE wk_crm_activities SET status = 'P'
      WHERE status = 'NS' AND activity_type IN ('C', 'M');

      UPDATE wk_crm_activities SET status = 'H'
      WHERE status = 'C' AND activity_type IN ('C', 'M');

      UPDATE wk_crm_activities SET status = 'NH'
      WHERE status = 'D' AND activity_type IN ('C', 'M');
    SQL
  end
end
