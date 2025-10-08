module Wkcrmdashboard
  module Graph004ScheduledVsCompletedActivities
    include WkcrmHelper

    def chart_data(param = {})
      to = param[:to].end_of_week
      from = param[:to].beginning_of_week

      # Count all activity types
      scheduled_counts = count_weekly(from, to, 'NS')
      completed_counts = count_weekly(from, to, 'C')

      {
        graphName: "#{l(:label_activity_plural)} #{l(:label_scheduled)} #{l(:label_vs)} #{l(:label_completed)}",
        chart_type: 'bar',
        stacked: false,
        xTitle: l(:label_days),
        yTitle: l(:label_no_of_activities),
        fields: Date::ABBR_DAYNAMES.rotate(1),
        legentTitle1: l(:label_scheduled),
        legentTitle2: l(:label_completed),
        data1: scheduled_counts,
        data2: completed_counts
      }
    end

def get_detail_report(param = {})
  to = param[:to].end_of_week
  from = param[:to].beginning_of_week
  date_range = getFromDateTime(from)..getToDateTime(to)

  scheduled = WkCrmActivity.where(status: 'NS', start_date: date_range)
                            .order(start_date: :desc)

  completed = WkCrmActivity.where(status: 'C')
                            .where(end_date: date_range)
                            .or(WkCrmActivity.where(status: 'C', end_date: nil, start_date: date_range))
                            .order(end_date: :desc)

  activities = scheduled.map do |activity|
    {
      name: activity.name,
      type: acttypeHash[activity.activity_type],
      status: activityStatusHash[activity.status],
      start_date: activity.start_date&.localtime&.to_date,
      end_date: ''
    }
  end

  activities += completed.map do |activity|
    {
      name: activity.name,
      type: acttypeHash[activity.activity_type],
      status: activityStatusHash[activity.status],
      start_date: activity.start_date&.localtime&.to_date,
      end_date: (activity.end_date || activity.start_date)&.localtime&.to_date
    }
  end

  {
    header: {
      name: l(:field_subject),
      type: l(:label_activity_type),
      status: l(:field_status),
      start_date: l(:label_start_date),
      end_date: l(:label_end_date)
    },
    data: activities
  }
end


    private

    def count_weekly(from, to, status)
      counts = [0] * 7

      if status == 'NS'
        activities = WkCrmActivity.where(
          status: 'NS',
          start_date: getFromDateTime(from)..getToDateTime(to)
        )
      else
        activities = WkCrmActivity.where(status: 'C')
                                  .where(end_date: getFromDateTime(from)..getToDateTime(to))
                                  .or(
                                    WkCrmActivity.where(
                                      status: 'C',
                                      end_date: nil,
                                      start_date: getFromDateTime(from)..getToDateTime(to)
                                    )
                                  )
      end

      activities.each do |activity|
        date = (status == 'NS') ? activity.start_date : (activity.end_date || activity.start_date)
        next unless date
        weekday = date.localtime.to_date.cwday  # 1 = Monday, ..., 7 = Sunday
        counts[weekday - 1] += 1
      end

      counts
    end

  end
end
