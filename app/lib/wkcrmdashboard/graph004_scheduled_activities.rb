module Wkcrmdashboard
  module Graph004ScheduledActivities
    include WkcrmHelper

    def chart_data(param = {})
      to = param[:to].end_of_week
      from = param[:to].beginning_of_week
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
      data[:data1] = count_weekly_scheduled('C', from, to)
      data[:data2] = count_weekly_scheduled('M', from, to)
      data[:data3] = count_weekly_scheduled('T', from, to)

      data
    end

    def getDetailReport(param = {})
      to = param[:to].end_of_week
      from = param[:to].beginning_of_week
      activities = WkCrmActivity
        .where(
          start_date: getFromDateTime(from)..getToDateTime(to),
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

    def count_weekly_scheduled(activity_type, from, to)
      # Initialize counts for Mon..Sun
      counts = [0] * 7
      scope = WkCrmActivity.where(
        start_date: getFromDateTime(from)..getToDateTime(to),
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
