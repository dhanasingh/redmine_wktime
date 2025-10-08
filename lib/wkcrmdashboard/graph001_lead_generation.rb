module Wkcrmdashboard
  module Graph001LeadGeneration
    include WkcrmHelper

    def chart_data(param = {})
      to = param[:to].end_of_week
      from = param[:to].beginning_of_week

      data = {
        graphName: l(:label_lead_generated),
        chart_type: "line",
        xTitle: l(:label_weekdays),
        yTitle: l(:label_cumulative_ratio),
        legentTitle1: l(:label_created_lead)
      }

      # Always show all 7 days
      data[:fields] = Date::ABBR_DAYNAMES.rotate(1)

      # Get leads in range
      leads = getLeadsForRange(from, to)

      # Count leads per weekday (Mon=1..Sun=7)
      daily_counts = [0] * 7
      leads.each do |lead|
        next unless lead.created_at
        weekday = lead.created_at.to_date.cwday
        daily_counts[weekday - 1] += 1
      end

      # Compute cumulative sums
      cumulative_sums = []
      sum = 0
      daily_counts.each do |count|
        sum += count
        cumulative_sums << sum
      end

      # Compute ratios
      cumulative_ratios = cumulative_sums.each_with_index.map do |cum, idx|
        day_number = idx + 1
        (cum.to_f / day_number).round(4)
      end

      # Check if the param[:to] is in the current week
      current_week = Date.today.cweek
      current_year = Date.today.cwyear

      param_week = to.cweek
      param_year = to.cwyear

      if current_week == param_week && current_year == param_year
        # It's this week - blank out future days
        today_index = Date.today.cwday - 1
        cumulative_ratios = cumulative_ratios.each_with_index.map do |val, idx|
          idx <= today_index ? val : nil
        end
      end

      data[:data1] = cumulative_ratios
      data
    end

    def get_detail_report(param = {})
      to = param[:to].end_of_week
      from = param[:to].beginning_of_week

      leads = getLeadsForRange(from, to).order(created_at: :desc)

      header = {
        name: l(:field_name),
        date: "#{l(:label_generated)} #{l(:label_date)}",
        status: l(:field_status)
      }

      data = leads.map do |lead|
        {
          name: lead&.contact&.name,
          date: lead.created_at&.to_date,
          status: getLeadStatusHash[lead.status]
        }
      end

      { header: header, data: data }
    end

    private

    def getLeadsForRange(from, to)
      WkLead
        .joins(:contact)
        .where(
          status: 'N',
          created_at: getFromDateTime(from)..getToDateTime(to),
          "wk_crm_contacts.contact_type" => ["C", "SC"]
        )
    end
  end
end
