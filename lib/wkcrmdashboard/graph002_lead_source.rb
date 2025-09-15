module Wkcrmdashboard
  module Graph002LeadSource
    include WkcrmHelper

    def chart_data(param = {})
      to = param[:to].end_of_week
      from = param[:to].beginning_of_week
      data = {
        graphName: "Leads by source", chart_type: "doughnut", xTitle: l(:field_hours), yTitle: l(:label_day_plural), legentTitle1: l(:label_lead_source)
      }
      entries = getLeads(from, to)
      entries = entries.group(:lead_source_id).select("wk_leads.lead_source_id, COUNT(wk_leads.id) AS source_count").order("source_count DESC")
      expenses = entries.map{|c| [c.lead_source.name.to_s, c.source_count]  if c.lead_source_id}.compact.to_h
      data[:fields] = expenses.keys
      data[:data1] = expenses.values
      return data
    end

    def get_detail_report(param = {})
      to = param[:to].end_of_week
      from = param[:to].beginning_of_week
      entries = getLeads(from, to)

      header = { user: l(:field_name), lead_source: l(:label_lead_source), date: l(:label_generated) +" "+ l(:label_date) }

      data = entries.map do |e|
        {
          user: e&.contact&.name,
          lead_source: e&.lead_source&.name.to_s, 
          date: e.created_at.to_date,
        }
      end

      { header: header, data: data }
    end

    private

    def getLeads(from, to)
      WkLead.joins(:contact).where(created_at: getFromDateTime(from)..getToDateTime(to),wk_crm_contacts: { contact_type: 'C' })
    end
  end
end