class WksupplierorderentityController < WkorderentityController
  unloadable

	def newOrderEntity(parentId, parentType)	
		newSupOrderEntity(parentId, parentType)
	end
	
	def newSupOrderEntity(parentId, parentType)
		msg = ""
		
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
		getMainLocation + "\n" +  getAddress
	end
	
	def getPaymentController
		"wksupplierpayment"
	end
	
	def deletePermission
		validateERPPermission("A_PUR_PRVLG")
	end
	
	def check_permission		
		return validateERPPermission("B_PUR_PRVLG") || validateERPPermission("A_PUR_PRVLG") 
	end
	
	def check_crm_admin_and_redirect
	  unless validateERPPermission("A_PUR_PRVLG") 
	    render_403
	    return false
	  end
    end
	
	def getAccountLbl
		l(:label_supplier_account)
	end
	
	def additionalContactType
		false
	end
end
