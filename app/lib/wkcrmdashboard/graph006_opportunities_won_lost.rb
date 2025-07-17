module Wkcrmdashboard
  module Graph006OpportunitiesWonLost
    include WkcrmHelper
    include WkopportunityHelper

    def chart_data(param={})
      to = param[:to].end_of_month
      data = {
        graphName: "#{l(:label_opportunity_plural)} #{l(:label_won)} #{l(:label_vs)} #{l(:label_lost)}",
        chart_type: "bar",
        xTitle: l(:label_months),
        yTitle: l(:label_opportunity_plural),
        legentTitle1: l(:label_won),
        legentTitle2: l(:label_lost)
      }
      data[:fields] = (Array.new(12){|indx| month_name(((to.month - 1 - indx) % 12) + 1).first(3)}).reverse
      # Opportunities won vs lost
      won_id = getCrmEnumId('SS', 'Closed Won')
      won_oppr =  getOpportunities(to, won_id) #Closed WON
      won_oppr = won_oppr.group(getDatePart("latest.status_date","month"))
      .select(getDatePart("latest.status_date","month","month_val"), +"count("+getDatePart("latest.status_date","month")+") oppr_count")

      wonOpprData = [0]*12
      won_oppr.map{|l| wonOpprData[to.month - l.month_val] = l.oppr_count }
      wonOpprData.reverse!
      
      lost_id = getCrmEnumId('SS', 'Closed Lost')
      lost_oppr =  getOpportunities(to, lost_id) #Closed Lost
      lost_oppr = lost_oppr.group(getDatePart("latest.status_date","month"))
      .select(getDatePart("latest.status_date","month","month_val"), +"count("+getDatePart("latest.status_date","month")+") oppr_count")

      lostOpprData = [0]*12
      lost_oppr.map{|l| lostOpprData[to.month - l.month_val] = l.oppr_count }
      lostOpprData.reverse!
      data[:data1] = wonOpprData
      data[:data2] = lostOpprData
      return data
    end

    def getDetailReport(param = {})
      to_date = param[:to].end_of_month
      enum_ids = getCrmEnumId('SS', ['Closed Won','Closed Lost'])
      opportunities = getOpportunities(to_date, enum_ids)
        header = {
          name: l(:field_name),
          stage: l(:label_txn_sales_stage),
          amount: l(:field_amount),
          close_date: l(:label_expected_date_to_close_project)
        }
        data = opportunities.map do |oppr|
          oppEntry = WkOpportunity.where(id: oppr.status_for_id).first
          {
            name: oppEntry.name || '',
            stage: getSaleStageHash[oppr.status.to_i],
            amount: oppEntry.amount,
            close_date: oppEntry.close_date.to_date
          }
        end
        { header: header, data: data }
    end

    private

    def getOpportunities(to, status)
      WkStatus.joins("INNER JOIN  (SELECT status_for_id, MAX(status_date) AS status_date FROM wk_statuses 
        WHERE wk_statuses.status_date BETWEEN '#{getFromDateTime(to - 12.months + 1.days)}' AND '#{getToDateTime(to)}' 
        AND wk_statuses.status_for_type = 'WkOpportunity'
        GROUP BY status_for_id) latest 
        ON wk_statuses.status_date = latest.status_date AND wk_statuses.status_for_id = latest.status_for_id").where(wk_statuses: { status: status })
    end

    def getCrmEnumId(enum_type, name)
      records = WkCrmEnumeration.where({enum_type: enum_type, name: name})
      ids = name.is_a?(Array) ? records.pluck(:id) : records.first&.id
    end
  end
end
