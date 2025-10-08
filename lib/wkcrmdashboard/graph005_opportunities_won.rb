module Wkcrmdashboard
  module Graph005OpportunitiesWon
    include WkcrmHelper
    include WkopportunityHelper

    def chart_data(param = {})
      to = param[:to].end_of_month
      from = (to - 11.months).beginning_of_month

      data = {
        graphName: "#{l(:label_opportunity_plural)} #{l(:label_won)}",
        chart_type: "line",
        xTitle: l(:label_months),
        yTitle: l(:field_amount),
        legentTitle1: l(:label_won)
      }

      # Month labels: Jan, Feb, etc.
      data[:fields] = (0..11).map do |i|
        date = from + i.months
        "#{month_name(date.month).first(3)}"
      end

      # Get 'Closed Won' enum ID
      won_id = getCrmEnumId('SS', 'Closed Won')

      # Get opportunities in 'Closed Won' status
      won_oppr = getOpportunities(to, won_id)
        .joins("LEFT JOIN wk_opportunities ON wk_opportunities.id = wk_statuses.status_for_id")
        .where("wk_opportunities.amount IS NOT NULL")
        .group("EXTRACT(YEAR FROM latest.status_date)", "EXTRACT(MONTH FROM latest.status_date)")
        .select(
          "EXTRACT(YEAR FROM latest.status_date) AS year_val",
          "EXTRACT(MONTH FROM latest.status_date) AS month_val",
          "SUM(wk_opportunities.amount) AS oppr_amount"
        )

      # Initialize 12-month amount array
      monthly_amounts = Array.new(12, 0)

      # Fill the array with summed values per month
      won_oppr.each do |record|
        record_date = Date.new(record.year_val.to_i, record.month_val.to_i, 1)
        index = ((record_date.year - from.year) * 12 + record_date.month - from.month)
        monthly_amounts[index] = record.oppr_amount.to_f if index.between?(0, 11)
      end

      # Build cumulative values
      cumulative_amounts = []
      total = 0
      monthly_amounts.each do |value|
        total += value
        cumulative_amounts << total
      end

      data[:data1] = cumulative_amounts
      return data
    end

    def get_detail_report(param = {})
      to_date = param[:to].end_of_month
      won_id = getCrmEnumId('SS', 'Closed Won')
      opportunities = getOpportunities(to_date, won_id)

      header = {
        name: l(:field_name),
        stage: l(:label_txn_sales_stage),
        amount: l(:field_amount),
        close_date: l(:label_expected_date_to_close_project)
      }

      data = opportunities.map do |oppr|
        opp_entry = WkOpportunity.find_by(id: oppr.status_for_id)
        {
          name: opp_entry&.name || '',
          stage: getSaleStageHash[oppr.status.to_i],
          amount: opp_entry&.amount,
          close_date: opp_entry&.close_date&.to_date
        }
      end

      { header: header, data: data }
    end

    private

    def getOpportunities(to, status)
      from = (to - 11.months).beginning_of_month
      WkStatus.joins("
        INNER JOIN (
          SELECT status_for_id, MAX(status_date) AS status_date
          FROM wk_statuses
          WHERE status_date BETWEEN '#{getFromDateTime(from)}' AND '#{getToDateTime(to)}'
          AND status_for_type = 'WkOpportunity'
          GROUP BY status_for_id
        ) latest
        ON wk_statuses.status_date = latest.status_date 
        AND wk_statuses.status_for_id = latest.status_for_id
      ")
      .where(status: status)
    end

    def getCrmEnumId(enum_type, name)
      records = WkCrmEnumeration.where(enum_type: enum_type, name: name)
      name.is_a?(Array) ? records.pluck(:id) : records.first&.id
    end
  end
end
