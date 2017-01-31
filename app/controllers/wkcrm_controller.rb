class WkcrmController < WkbaseController
  unloadable
  include WkcrmHelper
	def index
	end
	
	def lead_conv_rpt	
		@from = session[:wkreport][:from].beginning_of_day
		@to = session[:wkreport][:to].end_of_day
		@leadList = getLeadList(@from,@to)
		render :action => 'lead_conv_rpt', :layout => false
	end
	
	def sales_act_rpt
		@to = session[:wkreport][:to].end_of_day
		@from = session[:wkreport][:from].beginning_of_day
		#@profitLossEntries = getTransDetails(@from,@to)
		render :action => 'sales_act_rpt', :layout => false
	end 
  
	def updateAddress
		wkAddress = nil
		addressId = nil
	    if params[:address_id].blank? || params[:address_id].to_i == 0
		    wkAddress = WkAddress.new 
	    else
		    wkAddress = WkAddress.find(params[:address_id].to_i)
	    end
		# For Address table
		wkAddress.address1 = params[:address1]
		wkAddress.address2 = params[:address2]
		wkAddress.work_phone = params[:work_phone]
		wkAddress.city = params[:city]
		wkAddress.state = params[:state]
		wkAddress.pin = params[:pin]
		wkAddress.country = params[:country]
		wkAddress.fax = params[:fax]
		wkAddress.mobile = params[:mobile]
		wkAddress.email = params[:email]
		wkAddress.website = params[:website]
		wkAddress.department = params[:department]
		if wkAddress.valid?
			wkAddress.save
			addressId = wkAddress.id
		end		
		addressId
	end
  
	def getActRelatedIds
		relatedArr = ""	
		relatedId = nil
		if params[:related_type] == "WkOpportunity"
			relatedId = WkOpportunity.all.order(:name)
		elsif params[:related_type] == "WkLead"
			relatedId = WkLead.where.not(:status => 'C')
		elsif params[:related_type] == "WkCrmContact"
			relatedId = WkCrmContact.where.not(:parent_type => 'WkLead').order(:last_name)
		else
			relatedId = WkAccount.where(:account_type => 'A').order(:name)
		end
		if !relatedId.blank?
			relatedId.each do | entry|	
				if params[:related_type] == "WkLead"
					relatedArr <<  entry.id.to_s() + ',' + entry.contacts.last_name.to_s()  + "\n" 
				elsif params[:related_type].to_s == "WkCrmContact"
					relatedArr <<  entry.id.to_s() + ',' + entry.last_name.to_s()  + "\n"
				else
					relatedArr <<  entry.id.to_s() + ',' + entry.name.to_s()  + "\n" 
				end
			end
		end
		respond_to do |format|
			format.text  { render :text => relatedArr }
		end
    end

end
