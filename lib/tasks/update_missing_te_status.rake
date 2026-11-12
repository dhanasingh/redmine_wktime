namespace :erpmine do
  desc 'Add missing time and expense entry statuses and update sheet statuses'
  task update_missing_te_status: :environment do
    [Wktime, TimeEntry, Wkexpense, WkExpenseEntry, WkStatus].each do |model|
      raise "Missing database table: #{model.table_name}" unless model.table_exists?
    end

    created_status_count = 0
    updated_sheet_count = 0

    [[Wktime, TimeEntry], [Wkexpense, WkExpenseEntry]].each do |sheet_model, entry_model|
      existing_entry_status_ids = WkStatus.where(status_for_type: entry_model.name)
                                          .where.not(status_for_id: nil)
                                          .select(:status_for_id)

      # A sheet supplies the submission history for its user's entries that week.
      sheet_model.find_each do |sheet|
        week_entries = entry_model.where(user_id: sheet.user_id,
                                         spent_on: sheet.begin_date..(sheet.begin_date + 6))

        WkStatus.transaction do
          week_entries.where.not(id: existing_entry_status_ids).find_each do |entry|
            was_submitted = %w[s a r pa pr].include?(sheet.status) &&
                            (!sheet.submitted_on || entry.created_on.to_date <= sheet.submitted_on)
            WkStatus.create!(status_for_type: entry_model.name, status_for_id: entry.id,
                             status: was_submitted ? 's' : 'n',
                             status_date: was_submitted ? (sheet.submitted_on || sheet.updated_at) : entry.created_on,
                             status_by_id: was_submitted ? (sheet.submitter_id || sheet.user_id) : entry.user_id)
            created_status_count += 1
          end

          entry_statuses = week_entries.includes(:wkstatus).map { |entry| entry.wkstatus.status }
          next if entry_statuses.empty?

          sheet_status = Wktime.status_from_entries(entry_statuses)
          if sheet.status != sheet_status
            sheet.update_columns(status: sheet_status)
            updated_sheet_count += 1
          end
        end
      end

      # Entries outside a sheet have no submission history and are new.
      entry_model.where.not(id: existing_entry_status_ids).find_each do |entry|
        WkStatus.create!(status_for_type: entry_model.name, status_for_id: entry.id,
                         status: 'n', status_date: entry.created_on,
                         status_by_id: entry.user_id)
        created_status_count += 1
      end
    end

    puts "Created #{created_status_count} missing entry status records; updated #{updated_sheet_count} sheet statuses."
  end
end
