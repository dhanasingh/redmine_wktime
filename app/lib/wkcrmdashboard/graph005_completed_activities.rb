module Wkcrmdashboard
  module Graph005CompletedActivities
    include WkcrmHelper

    def chart_data(param = {})
      to_date = param[:to].end_of_week

      data = {
        graphName: "#{l(:label_activity_plural)} #{l(:label_completed)}",
        chart_type: "bar",
        xTitle: l(:label_days),
        yTitle: l(:label_no_of_activities),
        legentTitle1: l(:label_call),
        legentTitle2: l(:label_meeting),
        legentTitle3: l(:label_task)
      }

      # Weekday labels: Mon, Tue, ..., Sun
      data[:fields] = Date::ABBR_DAYNAMES.rotate(1)

      # Completed activities with status = 'C' in past 7 days
      data[:data1] = count_weekly_completed('C', to_date)
      data[:data2] = count_weekly_completed('M', to_date)
      data[:data3] = count_weekly_completed('T', to_date)

      data
    end

    def getDetailReport(param = {})
      to_date = param[:to].end_of_week
      from_date = to_date - 6.days

      activities = WkCrmActivity
        .where(
          end_date: getFromDateTime(from_date)..getToDateTime(to_date),
          status: 'C'
        )
        .order(end_date: :desc)

      {
        header: {
          name: l(:field_subject),
          type: l(:label_activity_type),
          start_date: "#{l(:label_start)} #{l(:label_date)}",
          end_date: "#{l(:label_completed)} #{l(:label_date)}"
        },
        data: activities.map do |activity|
          {
            name: activity.name,
            type: acttypeHash[activity.activity_type],
            start_date: activity.start_date&.to_date,
            end_date: activity.end_date&.to_date
          }
        end
      }
    end

    private

    def count_weekly_completed(activity_type, to_date)
      # Initialize counts for Mon..Sun
      counts = [0] * 7

      from_date = to_date - 6.days
      scope = WkCrmActivity.where(
        end_date: getFromDateTime(from_date)..getToDateTime(to_date),
        activity_type: activity_type,
        status: 'C'
      )

      scope.each do |activity|
        next unless activity.end_date
        weekday = activity.end_date.to_date.cwday  # 1 (Mon) .. 7 (Sun)
        counts[weekday - 1] += 1
      end

      counts
    end
  end
end
