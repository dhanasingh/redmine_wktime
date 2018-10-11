class WkcustomfieldsController < ApplicationController
  unloadable
  
  def index
    @wkcustomfields = CustomField.where(field_format: ['company', 'wk_lead', 'crm_contact'])
  end

end
