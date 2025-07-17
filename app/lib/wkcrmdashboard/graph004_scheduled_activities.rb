module Wkcrmdashboard
  module Graph004ScheduledActivities
    include WkcrmHelper

    def chart_data(param = {})
      to_date = param[:to].end_of_week
      data = {
        graphName: "Activities Scheduled",
        chart_type: "bar",
        xTitle: l(:label_months),
        yTitle: l(:label_no_of_activities),
        legentTitle1: l(:label_call),
        legentTitle2: l(:label_meeting),
        legentTitle3: l(:label_task)
      }

      # Weekday labels: Mon, Tue, ... Sun
      data[:fields] = Date::ABBR_DAYNAMES.rotate(1)

      # Fill datasets
      data[:data1] = count_weekly_scheduled('C', to_date)
      data[:data2] = count_weekly_scheduled('M', to_date)
      data[:data3] = count_weekly_scheduled('T', to_date)

      data
    end

    def getDetailReport(param = {})
      to_date = param[:to].end_of_week
      from_date = to_date - 6.days
      activities = WkCrmActivity
        .where(
          start_date: getFromDateTime(from_date)..getToDateTime(to_date),
          status: 'NS'
        )
        .order(start_date: :desc)

      {
        header: {
          name: l(:field_subject),
          type: l(:label_activity_type),
          date: "#{l(:label_start)} #{l(:label_date)}"
        },
        data: activities.map do |activity|
          {
            name: activity.name,
            type: acttypeHash[activity.activity_type],
            date: activity.start_date&.localtime&.to_date
          }
        end
      }
    end

    private

    def count_weekly_scheduled(activity_type, to_date)
      # Initialize counts for Mon..Sun
      counts = [0] * 7

      from_date = to_date - 6.days
      scope = WkCrmActivity.where(
        start_date: getFromDateTime(from_date)..getToDateTime(to_date),
        activity_type: activity_type,
        status: 'NS'
      )

      scope.each do |activity|
        next unless activity.start_date
        weekday = activity.start_date&.localtime&.to_date.cwday  # 1 (Mon) .. 7 (Sun)
        counts[weekday - 1] += 1
      end

      counts
    end
  end
end
