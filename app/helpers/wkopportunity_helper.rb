module WkopportunityHelper
include WktimeHelper
include WkinvoiceHelper
include WkcrmHelper
include WkcrmenumerationHelper

def getSaleStageHash
    salestage = WkCrmEnumeration.where(:enum_type => "SS").order(enum_type: :asc, name: :asc).pluck(:id, :name)
    salestagehash = Hash[*salestage.flatten]
    salestagehash
end

def get_sales_stage(entry)
    entry&.wkstatus&.order(status_date: :desc)&.first&.status.to_i
end
end
