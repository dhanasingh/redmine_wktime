module WkDashboard
  include WkpayrollHelper
  include WkcrmHelper

  def chart_data(param={})
    data = {
      graphName: l(:label_invoice_payment), chart_type: "line", xTitle: l(:label_months), yTitle: l(:field_amount),
      legentTitle1: l(:label_invoice), legentTitle2: l(:label_txn_payment),
      url: {controller: "wkreport", action: "index", report_type: "report_lead_conversion_web"}
    }
    getFinancialDates(param)
    data[:fields] = (Array.new(12){|indx| month_name(((@endDate.month - 1 - indx) % 12) + 1).first(3)}).reverse

    invoices = getInvoiceEntries.joins(:invoice_items)
      .select(getDatePart("wk_invoices.invoice_date","month", "month_val"), +"sum(wk_invoice_items.amount) invoice_total")
      .group(getDatePart("wk_invoices.invoice_date", "month"))
    invoiceData = [0]*12
    invoices.map{|l| invoiceData[@endDate.month - l.month_val] = l.invoice_total}
    invoiceData.reverse!
    invoiceData.each_with_index {|amt, index| invoiceData[index] = amt + invoiceData[index-1] if index != 0}
    data[:data1] = invoiceData

    payments = getPaymentEntries.joins(:payment_items)
      .where("wk_payment_items.is_deleted = ?", false)
      .select(getDatePart("wk_payments.payment_date","month", "month_val"), +"sum(wk_payment_items.amount) payment_total")
      .group(getDatePart("wk_payments.payment_date", "month"))
    paymentData = [0]*12
    payments.map{|l| paymentData[@endDate.month - l.month_val] = l.payment_total}
    paymentData.reverse!
    paymentData.each_with_index {|amt, index| paymentData[index] = amt + paymentData[index-1] if index != 0}
    data[:data2] = paymentData
    return data
  end

  def getFinancialDates(param={})
    to = param[:to]
    if to.month < getFinancialStart.to_i
      @startDate = ("01/"+getFinancialStart.to_s+"/"+(to.year - 1).to_s).to_datetime - 1.second
      @endDate = ("01/"+getFinancialStart.to_s+"/"+(to.year).to_s).to_date - 1.second
    else
      @startDate = ("01/"+getFinancialStart.to_s+"/"+to.year.to_s).to_datetime - 1.second
      @endDate = ("01/"+getFinancialStart.to_s+"/"+(to.year + 1).to_s).to_date - 1.second
    end
  end

  def dataset(param={})
    getFinancialDates(param)
    invoiceEntries = getInvoiceEntries
    paymentEntries = getPaymentEntries
    header = {name: l(:field_name), date: l(:label_date), type: l(:field_type), amount: l(:field_amount)}
    data1 = invoiceEntries.map do |e|
      items = e&.invoice_items
      { name: e&.parent&.name, date: e.invoice_date.to_date, type: l(:label_invoice), amount: items&.first&.currency.to_s + items&.sum(:amount).to_s }
    end
    data2 = paymentEntries.map do |e|
      items = e&.payment_items&.where(is_deleted: false)
      { name: e&.parent&.name, date: e.payment_date.to_date, type: l(:label_txn_payment), amount: items&.first&.currency.to_s + items&.sum(:amount).to_s }
    end
    return {header: header, data: data1+data2}
  end

  private

  def getInvoiceEntries
    WkInvoice.where(:invoice_date => getFromDateTime(@startDate) .. getToDateTime(@endDate))
  end

  def getPaymentEntries
    WkPayment.where("wk_payments.payment_date BETWEEN ? AND ?", getFromDateTime(@startDate), getToDateTime(@endDate))
  end
end