namespace :ERPmine do
  desc "Setup initial ERPmine data"

  task setup_initial_data: :environment do
    if WkSetting.where(name: 'leave_settings').where.not(value: [nil, '']).exists? || WkLocation.exists?
      puts "Failed already data  present."
      exit
    end

    Project.transaction do
      begin
        puts "Setting up initial ERPmine data..."
        setup_leave_and_expense
        setup_location_and_permission
        puts "Initial ERPmine data setup completed successfully."
      rescue => e
        puts e.to_json
        puts "Failed to load: #{e.message}"
        raise ActiveRecord::Rollback
      end
    end
  end

  def setup_leave_and_expense
    # --- Define initial projects, trackers, and issues ---
    projects = [
      {
        identifier: 'hr',
        name: 'HR',
        description: 'HR Management',
        issues: [
          { subject: 'Casual Leave', short: 'CL', accrual: '8', multiplier: '1', year_after: '', reset_month: '0' },
          { subject: 'Sick Leave', short: 'SL', accrual: '8', multiplier: '1', year_after: '', reset_month: '1' },
          { subject: 'Public Holiday', short: 'PH', accrual: '8', multiplier: '1', year_after: '', reset_month: '0' },
          { subject: 'Maternity Leave', short: 'ML', accrual: '', multiplier: '1', year_after: '', reset_month: '0' },
          { subject: 'Loss of Pay', short: 'LP', accrual: '', multiplier: '1', year_after: '', reset_month: '0' }
        ],
        tracker: 'Leave',
        activities: ['Leave']
      },
      {
        identifier: 'expense',
        name: 'Expense',
        description: 'Expense Management',
        issues: [
          "Petrol", "Visa", "Telephone", "Gift", "Insurance", "Miscellaneous", "Laundry", "Conference",
          "Shipping", "Stationary", "Bus", "Toll", "Taxi", "Car Rental", "Hotel", "Air Ticket",
          "Dinner", "Lunch", "Breakfast"
        ],
        tracker: 'Expense',
        activities: [ 'Creadit Card', 'Cash', 'Cheque', 'Bank Transfer' ]
      }
    ]

    # --- Get admin user and default status ---
    admin = User.admin.first
    status = IssueStatus.first

    # --- Create projects, trackers, and issues ---
    projects.each do |proj_data|
      project = Project.new
      if Project.exists?(identifier: proj_data[:identifier])
        project.identifier = proj_data[:identifier] + "-default"
        project.name = proj_data[:name] + "-default"
      else
        project.identifier = proj_data[:identifier]
        project.name = proj_data[:name]
      end
      project.description = proj_data[:description]
      project.is_public = false
      project.enabled_module_names = Redmine::AccessControl.available_project_modules
      project.save!
      puts "Project '#{project.name}' saved."

      # --- Create and assign activities to project ---
      (proj_data[:activities] || []).each do |name|
        activity = TimeEntryActivity.find_or_create_by(name: name)
        unless project.time_entry_activities.exists?(activity.id)
          project.time_entry_activities << activity
          puts "Activity '#{activity.name}' assigned to project '#{project.name}'."
        end
      end

      # --- Create tracker and assign to project ---
      tracker = Tracker.new
      tracker.name = proj_data[:tracker]
      tracker.default_status_id = status.id
      tracker.core_fields = Tracker::CORE_FIELDS
      tracker.save!
      puts "Tracker '#{tracker.name}' saved."
      unless tracker.projects.include?(project)
        tracker.projects << project
        puts "Tracker '#{tracker.name}' assigned to project '#{project.name}'."
      end

      # --- Create issues for the project ---
      (proj_data[:issues] || []).each do |issue_data|
        subject = issue_data.is_a?(String) ? issue_data : issue_data[:subject]
        issue = Issue.new
        issue.subject = subject
        issue.project_id = project.id
        issue.tracker_id = tracker.id
        issue.author_id = admin.id
        issue.status_id = status.id
        issue.save!
        puts "Issue '#{issue.subject}' saved in project '#{project.name}'."
      end
    end

    # --- Save leave_settings in wksettings table ---
    hr_project = Project.find_by(identifier: 'hr')
    if hr_project.present?
      hr_issues = projects.find { |p| p[:identifier] == 'hr' }[:issues]
      subject_map = hr_issues.index_by { |i| i[:subject] }
      leave_settings = Issue.where(project_id: hr_project.id).map do |issue|
        setting = subject_map[issue.subject]
        next unless setting.present?
        [
          issue.id,
          setting[:accrual],
          setting[:year_after],
          setting[:reset_month],
          setting[:short],
          setting[:multiplier]
        ].join('|')
      end.compact

      ws = WkSetting.find_by(name: 'leave_settings') || WkSetting.new
      ws.value = leave_settings.to_json
      ws.save!
      puts "WkSetting 'leave_settings' saved."

      # --- Get IDs for Public Holiday and Loss of Pay ---
      public_holiday = Issue.find_by(project_id: hr_project.id, subject: 'Public Holiday')
      loss_of_pay = Issue.find_by(project_id: hr_project.id, subject: 'Loss of Pay')
      public_holiday_id = public_holiday&.id&.to_s
      loss_of_pay_id    = loss_of_pay&.id&.to_s

      # --- Update or create plugin_redmine_wktime settings hash ---
      current = (Setting.plugin_redmine_wktime || {}).to_h
      current['wktime_holiday']   = public_holiday_id if public_holiday_id.present?
      current['wktime_loss_of_pay'] = loss_of_pay_id if loss_of_pay_id.present?
      Setting.plugin_redmine_wktime = current
      puts "Setting 'plugin_redmine_wktime' created."
    end
  end

  def setup_location_and_permission
    # --- Create default location ---
    loc_type = WkCrmEnumeration.create!(name: 'Office1', is_default: true, active: true, position: 1, enum_type: 'LT')
    location = WkLocation.create!(
      name: 'Office1',
      is_default: true,
      is_main: true,
      location_type_id: loc_type.id
    )
    puts "Location '#{location.name}' created."

    # --- Create group for permissions ---
    group = Group.create!(name: 'TE Admins')
    # Add the sole user (if exactly one user exists) and that user is admin
    group.users << User.admin.first if User.admin.exists? && User.admin.length == 1
    puts "Group '#{group.name}' created."

    # --- Create all ERPmine permissions ---
    WkPermission.where(short_name: "A_TE_PRVLG").each do |perm|
      WkGroupPermission.create!(group_id: group.id, permission_id: perm.id)
    end
    puts "Time & expense permissions assigned to the group '#{group.name}'."
  end
end