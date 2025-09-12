module Wkdashboard
  module Graph001ClockInUsersOverTime
    include WkcrmHelper
    include WktimeHelper

    def chart_data(param={})
      data = {
        graphName: l(:label_clockin_users), chart_type: "bar", xTitle: l(:field_hours), yTitle: l(:label_no_of_employees),
        legentTitle1: l(:label_no_of_employees)
      }
      entries = getEntries(param[:from])
      entries = entries.group(:user_id).select("wk_attendances.user_id, min(start_time) as clock_in")
      entries = entries.where("group_id IN (?)", param[:group_id]) if param[:group_id].present?
      time = [0] * 24
      entries.each{|c| time[c.clock_in.at_end_of_hour.hour] += 1 }
      data[:fields] = [*0..23]
      data[:data1] = time
      return data
    end

    def get_detail_report(param={})
      entries = getEntries(param[:from]).order("start_time asc")
      entries = entries.group(:user_id, :start_time, :end_time).select("wk_attendances.user_id, start_time, end_time")
      entries = entries.where("group_id IN (?)", param[:group_id]) if param[:group_id].present?
      header = {user: l(:field_user), date: l(:field_start_date), clockin: l(:label_clock_in), clockout: l(:label_clock_out)}
      data = entries.map{|e| { user_id: e.user.name, date: e&.start_time&.localtime&.to_date, clockin: e&.start_time&.localtime&.strftime('%R') || '', clockout: e&.end_time&.localtime&.strftime('%R') || '' }}
      return {header: header, data: data}
    end

    private

    def getEntries(from)
      WkAttendance.joins("LEFT JOIN groups_users ON groups_users.user_id = wk_attendances.user_id")
        .where("start_time BETWEEN ? AND ?", (getToDateTime(from)).beginning_of_day().utc, (getToDateTime(from)).end_of_day().utc)
    end
  end
end