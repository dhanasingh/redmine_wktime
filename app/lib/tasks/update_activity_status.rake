# plugins/redmine_wktime/lib/tasks/update_activity_status.rake

namespace :wk_crm_activities do
  desc 'Update activity statuses (P -> NS, H -> C, NH -> D)'
  task update_statuses: :environment do
    status_map = {
      'P' => 'NS',
      'H' => 'C',
      'NH' => 'D'
    }

    updated_count = 0
    WkCrmActivity.find_each do |activity|
      if status_map.key?(activity.status)
        old_status = activity.status
        activity.status = status_map[old_status]
        if activity.save
          puts "Updated ##{activity.id} from #{old_status} -> #{activity.status}"
          updated_count += 1
        else
          puts "Failed to update ##{activity.id} (#{old_status})"
        end
      end
    end

    puts "Finished updating #{updated_count} records."
  end
end
