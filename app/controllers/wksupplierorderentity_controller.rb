class WksupplierorderentityController < WkorderentityController
  unloadable

	def newOrderEntity(parentId, parentType)	
		newSupOrderEntity(parentId, parentType)
	end
	
	def newSupOrderEntity(parentId, parentType)
		msg = ""
		if params[:rfq_id].blank?
			flash[:error] = "Please select the RFQ \n"
			redirect_to :action => 'new'
		end		
		
		if !params[:project_id].blank? && params[:project_id] != '0'
			@projectsDD = Project.where(:id => params[:project_id].to_i).pluck(:name, :id)	
		end
		
		@rfqObj = WkRfq.find(params[:rfq_id].to_i)		
		@currency = params[:inv_currency]
		setTempEntity(params[:start_date], params[:end_date], parentId, parentType, params[:populate_items], params[:project_id])		
				
	end
	
	def getOrderAccountType
		'S'
	end
	
	def getOrderContactType
		'SC'
	end
	
	def needBlankProject
		false
	end	
	
	def addAdditionalTax
		true
	end
	
	def needChangedProject
		false
	end
end
