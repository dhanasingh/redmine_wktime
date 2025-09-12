module Wkdashboard
  module Graph003LeadGenerationVsConversion
    include WkcrmHelper

    def chart_data(param={})
      to = param[:to].end_of_month
      data = {
        graphName: l(:label_lead_generation), chart_type: "bar", xTitle: l(:label_months), yTitle: l(:label_no_of_leads),
        legentTitle1: l(:label_created_lead), legentTitle2: l(:label_converted_lead)
      }
      data[:fields] = (Array.new(12){|indx| month_name(((to.month - 1 - indx) % 12) + 1).first(3)}).reverse

      leads = getLeads(to)
      leads = leads.group(getDatePart("wk_leads.created_at","month"))
        .select(getDatePart("wk_leads.created_at","month","month_val"), +"count("+getDatePart("wk_leads.created_at","month")+") created_count")
      leadsData = [0]*12
      leads.map{|l| leadsData[to.month - l.month_val] = l.created_count }
      leadsData.reverse!
      # leadsData.each_with_index {|count, index| leadsData[index] = count + leadsData[index-1] if index != 0}
      data[:data1] = leadsData

      convLeads = WkLead.joins(:contact)
        .where(:status_update_on => getFromDateTime(to - 12.months + 1.days) .. getToDateTime(to), :status => "C", "wk_crm_contacts.contact_type"=> ["C", "SC"])
        .group(getDatePart("wk_leads.status_update_on","month"))
        .select(getDatePart("wk_leads.status_update_on","month","month_val"), +"count("+getDatePart("wk_leads.status_update_on","month")+") as convert_count")
      convleadsData = [0]*12
      convLeads.map{|l| convleadsData[to.month - l.month_val] = l.convert_count }
      convleadsData.reverse!
      # convleadsData.each_with_index {|count, index| convleadsData[index] = count + convleadsData[index-1] if index != 0}
      data[:data2] = convleadsData
      return data
    end

    def get_detail_report(param={})
      entries = getLeads(param[:to].end_of_month).order("created_at DESC")
      header = {name: l(:field_name), date: l(:label_generated) +" "+ l(:label_date), status: l(:field_status)}
      data = entries.map{|e| { name: e&.contact&.name, date: e.created_at.to_date, status: getLeadStatusHash[e.status] }}
      return {header: header, data: data}
    end

    private

    def getLeads(to)
      WkLead.joins(:contact).where(:created_at => getFromDateTime(to - 12.months + 1.days) .. getToDateTime(to), "wk_crm_contacts.contact_type"=> ["C", "SC"])
    end
  end
end