module Wkcrmdashboard
  module Graph005CompletedActivities
    include WkcrmHelper

    def chart_data(param = {})
      to = param[:to].end_of_week
      from = param[:to].beginning_of_week
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
      data[:data1] = count_weekly_completed('C', from, to)
      data[:data2] = count_weekly_completed('M', from, to)
      data[:data3] = count_weekly_completed('T', from, to)

      data
    end

    def getDetailReport(param = {})
      to = param[:to].end_of_week
      from = param[:to].beginning_of_week
      activities = WkCrmActivity.where(status: 'C').where(end_date: getFromDateTime(from)..getToDateTime(to))
                  .or(WkCrmActivity.where(status: 'C',end_date: nil,start_date: getFromDateTime(from)..getToDateTime(to)))
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
            start_date: activity.start_date&.localtime&.to_date,
            end_date: (activity&.end_date || activity&.start_date)&.localtime&.to_date
          }
        end
      }
    end

    private

    def count_weekly_completed(activity_type, from, to)
      # Initialize counts for Mon..Sun
      counts = [0] * 7

      activities = WkCrmActivity
          .where(status: 'C', activity_type: activity_type)
          .where(end_date: getFromDateTime(from)..getToDateTime(to))
          .or(
            WkCrmActivity.where(
              status: 'C',
              activity_type: activity_type,
              end_date: nil,
              start_date: getFromDateTime(from)..getToDateTime(to)
            )
          )
          .order(end_date: :desc)

        activities.each do |activity|
          next unless activity.end_date || activity.start_date
          weekday = (activity.end_date || activity.start_date)&.localtime&.to_date.cwday
          counts[weekday - 1] += 1
        end
      counts
    end
  end
end
