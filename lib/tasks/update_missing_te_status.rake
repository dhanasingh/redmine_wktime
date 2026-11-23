# Usage: bundle exec rake erpmine:update_missing_te_status RAILS_ENV=production YEAR=2026 USER_STATUS=active
#   YEAR         only that year's sheets and entries; omit for all years
#   USER_STATUS  active = active users only; omit or all = all users (inactive included)
namespace :erpmine do
  desc 'Add missing time and expense entry statuses and update sheet statuses'
  task update_missing_te_status: :environment do
    [Wktime, TimeEntry, Wkexpense, WkExpenseEntry, WkStatus].each do |model|
      raise "Missing database table: #{model.table_name}" unless model.table_exists?
    end

    year_input = ENV['YEAR'].to_s.strip
    abort "Invalid YEAR=#{year_input}: use a 4-digit year like YEAR=2026" unless year_input.empty? || year_input.match?(/\A\d{4}\z/)
    year_range = Date.new(year_input.to_i, 1, 1)..Date.new(year_input.to_i, 12, 31) if year_input.present?

    users = User.active if ENV['USER_STATUS'].to_s.strip.casecmp?('active')
    $stdout.sync = true
    started_at = Time.now
    puts "Started #{started_at.strftime('%Y-%m-%d %H:%M:%S')} (YEAR=#{year_input.presence || 'all'}, USER_STATUS=#{users ? 'active' : 'all'})"
    # insert_all skips attribute casting; cast so status_date is stored as create! stored it.
    status_date_type = WkStatus.type_for_attribute('status_date')

    total_without_status = 0
    created_status_count = 0
    updated_sheet_count = 0
    total_errors = 0
    # One pattern for the per-sheet-type lines and the Total line.
    summary = lambda do |records_label, records, created, updated, failed|
      text = "#{records_label}: #{records}, #{created} statuses created, #{updated} sheet statuses updated"
      failed > 0 ? "#{text}, #{failed} failed (see above)" : text
    end

    [[Wktime, TimeEntry], [Wkexpense, WkExpenseEntry]].each do |sheet_model, entry_model|
      sheet_name, records_label = sheet_model == Wktime ? ['Timesheet', 'Total time records'] : ['ExpenseSheet', 'Total expense records']
      to_process = 0
      success = 0
      sheets_updated = 0
      errors = 0
      failed_users = []
      # A sheet that starts up to 6 days before the year still holds that year's first entries.
      sheets = sheet_model.all
      sheets = sheets.where(begin_date: (year_range.begin - 6)..year_range.end) if year_range
      sheets = sheets.where(user_id: users) if users

      # Each user's entries are read once and matched to their sheets in memory (no query per sheet).
      sheets.distinct.pluck(:user_id).each do |user_id|
        user_sheets = sheets.where(user_id: user_id).order(:id).to_a
        begin_dates = user_sheets.map(&:begin_date)
        # [entry id, spent_on, created_on, status]; status is nil when the entry has none yet
        entry_rows = entry_model.where(user_id: user_id, spent_on: begin_dates.min..(begin_dates.max + 6))
                                .left_joins(:wkstatus).pluck(:id, :spent_on, :created_on, 'wk_statuses.status')
        rows_by_day = entry_rows.group_by { |row| row[1] }
        now = Time.now
        new_statuses = []
        sheet_ids_by_status = Hash.new { |hash, status| hash[status] = [] }

        user_sheets.each do |sheet|
          week_rows = (sheet.begin_date..(sheet.begin_date + 6)).flat_map { |day| rows_by_day.fetch(day, []) }
          next if week_rows.empty?

          week_rows.select { |row| row[3].nil? }.each do |row|
            entry_id, _spent_on, created_on = row
            was_submitted = %w[s a r pa pr].include?(sheet.status) &&
                            (!sheet.submitted_on || created_on.to_date <= sheet.submitted_on)
            new_statuses << { status_for_type: entry_model.name, status_for_id: entry_id,
                              status: was_submitted ? 's' : 'n',
                              status_date: status_date_type.cast(was_submitted ? (sheet.submitted_on || sheet.updated_at) : created_on),
                              status_by_id: was_submitted ? (sheet.submitter_id || sheet.user_id) : sheet.user_id,
                              created_at: now, updated_at: now }
            # A later sheet that covers the same day then sees the entry as already having a status.
            row[3] = new_statuses.last[:status]
          end

          sheet_status = Wktime.status_from_entries(week_rows.map(&:last))
          sheet_ids_by_status[sheet_status] << sheet.id if sheet.status != sheet_status
        end

        to_process += new_statuses.size
        # The user's statuses and sheet updates commit together, so a stopped run leaves no user half done.
        WkStatus.transaction do
          new_statuses.each_slice(1000) { |slice| WkStatus.insert_all!(slice) }
          sheet_ids_by_status.each do |status, sheet_ids|
            sheet_ids.each_slice(1000) { |ids| sheet_model.where(id: ids).update_all(status: status) }
          end
        end
        success += new_statuses.size
        sheets_updated += sheet_ids_by_status.values.sum(&:size)
      rescue => e
        # Skip the failed user and go on; a re-run picks up only what is still missing.
        errors += 1
        failed_users << user_id
        puts "#{sheet_name} user #{user_id} failed: #{e.message}"
      end

      # Entries outside a sheet have no submission history and are new.
      entries = entry_model.left_joins(:wkstatus).where(wk_statuses: { id: nil })
      entries = entries.where(spent_on: year_range) if year_range
      entries = entries.where(user_id: users) if users
      # A failed user's sheet entries still have no status; leave them for the re-run, not as outside-sheet entries.
      entries = entries.where.not(user_id: failed_users) if failed_users.any?
      entries.in_batches(of: 1000) do |batch|
        now = Time.now
        new_statuses = batch.pluck(:id, :user_id, :created_on).map do |entry_id, user_id, created_on|
          { status_for_type: entry_model.name, status_for_id: entry_id, status: 'n',
            status_date: status_date_type.cast(created_on), status_by_id: user_id,
            created_at: now, updated_at: now }
        end
        to_process += new_statuses.size
        WkStatus.insert_all!(new_statuses)
        success += new_statuses.size
      rescue => e
        errors += 1
        puts "#{sheet_name} entries outside a sheet, batch failed: #{e.message}"
      end
      total_without_status += to_process
      created_status_count += success
      updated_sheet_count += sheets_updated
      total_errors += errors
      nothing_done = to_process.zero? && sheets_updated.zero? && errors.zero?
      puts nothing_done ? "#{sheet_name}: skipped (nothing to update)" : summary.call(records_label, to_process, success, sheets_updated, errors)
    end

    puts summary.call('Total records', total_without_status, created_status_count, updated_sheet_count, total_errors)
    puts "Finished in #{Time.at(Time.now - started_at).utc.strftime('%H:%M:%S')}"
  end
end
