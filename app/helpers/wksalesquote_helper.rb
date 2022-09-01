module WksalesquoteHelper

  def salesQuoteList(parent_id, parent_type)
    invEntries = WkInvoice.includes(:invoice_items).where(parent_id: parent_id, parent_type: parent_type, invoice_type: 'SQ')
  end
end
