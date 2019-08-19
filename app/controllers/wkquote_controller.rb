# ERPmine - ERP for service industry
# Copyright (C) 2011-2017  Adhi software pvt ltd
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class WkquoteController < WksupplierorderentityController
  unloadable
  menu_item :wkrfq
  
  @@quotemutex = Mutex.new
  
	def editOrderEntity
		super
		unless params[:invoice_id].blank?
			@rfgQuoteEntry = WkRfqQuote.find(@invoice.rfq_quote.id) unless @invoice.blank?
		end
	end
	
	def newSupOrderEntity(parentId, parentType)
		msg = ""
		unless params[:rfq_id].blank?
			super
		else
			flash[:error] = l(:error_please_select_rfq) + " <br/>"
			redirect_to :action => 'new'
		end
	end
	
	# Synchronize the quote insert because maintain the sequence of invoice num key 
	def saveOrderInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)
		begin			
			@@quotemutex.synchronize do						
				addInvoice(parentId, parentType,  projectId, invDate,  invoicePeriod, isgenerate, getInvoiceType)				
			end				
		rescue => ex
		  logger.error ex.message
		end
	end	
	
	def saveOrderRelations
		isWon = params[:quote_won].blank? ? nil : params[:quote_won]
		winNote = params[:winning_note].blank? ? "" : params[:winning_note]
		saveRfqQuotes(params[:rfq_quote_id], params[:rfq_id].to_i, @invoice.id, isWon, winNote)
	end

	
	def getInvoiceType
		'Q'
	end
	
	def getLabelInvNum
		l(:label_quote_number)
	end
	
	def getLabelNewInv
		l(:label_new_quote)
	end
	
	def getHeaderLabel
		l(:label_quotes)
	end
	
	def getItemLabel
		l(:label_quote_items)
	end
	
	def getDateLbl
		l(:label_quote_date)
	end
	
	def addQuoteFields
		true
	end
	
	def getAdditionalDD
		"wkquote/quoteadditionaldd"
	end
	
	def editInvNumber
		true
	end
	
	def getOrderNumberPrefix
		'wktime_quote_no_prefix'
	end
	
	def getNewHeaderLbl
		l(:label_new_quote)
	end
	
	def getOrderContract(invoice)
		contractStr = nil
		rfq = invoice.rfq_quote.rfq
		unless rfq.blank?
			contractStr = rfq.name + "(#{rfq.id}) from " + rfq.start_date.to_formatted_s(:long) + " to " + rfq.end_date.to_formatted_s(:long)
		end
		contractStr
	end
	
	def getOrderComponetsId
		'wktime_quote_components'
	end
end
