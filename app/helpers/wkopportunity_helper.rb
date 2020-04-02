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
end
