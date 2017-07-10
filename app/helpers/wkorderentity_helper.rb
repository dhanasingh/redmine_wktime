module WkorderentityHelper
include WkcrmHelper

	def getRfqArray(needBlank)
		rfqArr = WkRfq.all.order(id: :desc).pluck(:name, :id)
		rfqArr.unshift(["",'']) if needBlank
		rfqArr
	end
	
	def getRfqQuoteArray(needBlank, id)
		rfqQuoteObj = WkRfqQuote.includes(:quote).where(:rfq_id => id, :is_won => true).order(:id) #getInvoiceIds(id, 'Q', true)
		rfqQuoteArr = rfqQuoteObj.collect {|i| [i.quote.invoice_number, i.quote.id]  }
		rfqQuoteArr.unshift(["",'']) if needBlank
		rfqQuoteArr
	end
	
	def getRfqPoArray(needBlank, id)
		rfqPoArr = Array.new
		unless id.blank? || id == 0
			rfqObj = WkRfq.find(id) 
			rfqPoArr = rfqObj.purchase_orders.collect {|i| [i.invoice_number, i.id]  }
		end
		rfqPoArr.unshift(["",'']) if needBlank
		rfqPoArr
	end
	
	def options_for_rfq_select(selectedValue, needBlank)
		options_for_select(getRfqArray(needBlank),
							selectedValue.blank? ? '' : selectedValue)
	end
	
	def options_for_rfqQuote_select(needBlank, id)
		options_for_select(getRfqQuoteArray(needBlank, id))
	end
	
	def options_for_rfqPO_select(needBlank, id)
		options_for_select(getRfqPoArray(needBlank, id))
	end
	
	def getInvoiceIds(rfqId, invoiceType, requireWonQuote)
		sqlStr = getRfqOrderSqlStr + " where rfq.id = #{rfqId}"
		if requireWonQuote
			sqlStr = sqlStr + " and rq.is_won = #{true} "
		end
		case invoiceType
			when 'Q'
			  invIdArr = WkRfq.find_by_sql(sqlStr).map {|i| i.quote_id }
			when 'PO'
			  invIdArr = WkRfq.find_by_sql(sqlStr).map {|i| i.purchase_order_id }
			else
			  invIdArr = WkRfq.find_by_sql(sqlStr).map {|i| i.supplier_inv_id }
		end
		invIdArr
	end
	
	def getRfqOrderSqlStr
		sqlStr = "select rfq.id as rfq_id, rq.quote_id, rp.purchase_order_id, rs.supplier_inv_id from wk_rfqs rfq" +
				" left join wk_rfq_quotes rq on (rfq.id = rq.rfq_id )" +
				" left join wk_po_quotes rp on (rp.quote_id = rq.quote_id)"+
				" left join wk_po_supplier_invoices rs on (rs.purchase_order_id = rp.purchase_order_id)"
	end
	
	def saveRfqQuotes(id, rfqId, quoteId, isWon, winningNote)
		rfqQuote = nil
		if id.blank?
			rfqQuote = WkRfqQuote.new
		else
			rfqQuote = WkRfqQuote.find(id)
		end
		rfqQuote.rfq_id = rfqId
		rfqQuote.quote_id = quoteId
		rfqQuote.is_won = isWon.blank? ? false : isWon
		if rfqQuote.is_won.blank? || rfqQuote.is_won_changed?		
			rfqQuote.won_date =  rfqQuote.is_won ? Date.today : nil
		end
		rfqQuote.winning_note = winningNote
		rfqQuote.save()
	end
	
	def savePurchaseOrderQuotes(id, poId, quoteId)
		poQuote = nil
		if id.blank?
			poQuote = WkPoQuote.new
		else
			poQuote = WkPoQuote.find(id)
		end
		poQuote.purchase_order_id = poId
		poQuote.quote_id = quoteId
		poQuote.save()
	end
	
	def savePoSupInv(id, poId, supInvId)
		poSI = nil
		if id.blank?
			poSI = WkPoSupplierInvoice.new
		else
			poSI = WkPoSupplierInvoice.find(id)
		end
		poSI.purchase_order_id = poId
		poSI.supplier_inv_id = supInvId
		poSI.save()
	end
	
end
