class WkcontactController < WkcrmController
  unloadable



	def index
	end

	def edit
	end
	
	def update
		errorMsg = nil
		if params[:contact_id].blank?
		    wkContact = WkCrmContact.new 
	    else
		    wkContact = WkCrmContact.find(params[:contact_id].to_i)
	    end
		# For Contact table
		wkContact.assigned_user_id = params[:assigned_user_id]
		wkContact.first_name = params[:first_name]
		wkContact.last_name = params[:last_name]
		wkContact.address_id = params[:address_id]
		wkContact.title = params[:contact_title]
		wkContact.description = params[:description]
		wkContact.department = params[:department]
		wkContact.salutation = params[:salutation]
		wkContact.created_by_user_id = User.current.id if wkContact.new_record?
		wkContact.updated_by_user_id = User.current.id
		addrId = updateAddress
		unless addrId.blank?
			wkContact.address_id = addrId
		end
		unless wkContact.valid?		
			errorMsg = wkContact.errors.full_messages.join("<br>")	
		else
			wkContact.save
		end
		
		if errorMsg.blank?
			redirect_to :controller => 'wkcontact',:action => 'index' , :tab => 'wkcontact'
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg
		    redirect_to :controller => 'wkcontact',:action => 'edit'
		end
		
	end

end
