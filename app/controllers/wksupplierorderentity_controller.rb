class WksupplierorderentityController < WkorderentityController
  unloadable

	def newOrderEntity(parentId, parentType)	
		newSupOrderEntity(parentId, parentType)
	end
	
	def newSupOrderEntity(parentId, parentType)
		msg = ""
		# if params[:rfq_id].blank?
			# flash[:error] = "Please select the RFQ \n"
			# redirect_to :action => 'new'
		# end
		unless params[:rfq_id].blank?		
		
			if !params[:project_id].blank? && params[:project_id] != '0'
				@projectsDD = Project.where(:id => params[:project_id].to_i).pluck(:name, :id)	
			end
			
			@rfqObj = WkRfq.find(params[:rfq_id].to_i)		
			@currency = params[:inv_currency]
			setTempEntity(params[:start_date], params[:end_date], parentId, parentType, params[:populate_items], params[:project_id])
		end
				
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
	
	def getAccountDDLbl
		l(:label_supplier_account)
	end
	
	def getSupplierAddress(invoice)
		invoice.parent.name + "\n" + (invoice.parent.address.blank? ? "" : invoice.parent.address.fullAddress)
	end
	
	def getCustomerAddress(invoice)
		Setting.plugin_redmine_wktime['wktime_company_name'] + "\n" +  Setting.plugin_redmine_wktime['wktime_company_address']
	end
	
	def getPaymentController
		"wksupplierpayment"
	end
	
	def deletePermission
		isModuleAdmin('wktime_pur_admin')
	end
	
	def check_permission		
		return isModuleAdmin('wktime_pur_group') || isModuleAdmin('wktime_pur_admin') 
	end
	
	def check_crm_admin_and_redirect
	  unless isModuleAdmin('wktime_pur_admin') 
	    render_403
	    return false
	  end
    end
end
