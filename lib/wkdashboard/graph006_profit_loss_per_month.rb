module Wkdashboard
  module Graph006ProfitLossPerMonth
    include WkaccountingHelper
    include WkpayrollHelper
    include WkcrmHelper
    include WktimeHelper

    def chart_data(param={})
      data = { graphName: l(:label_profit_loss), chart_type: "line", xTitle: l(:label_months), yTitle: l(:field_amount),
        legentTitle1: l(:label_income), legentTitle2: l(:label_total_expense)
      }

      profit = getProfits(param[:to])
      month_count = @endDate >= Date.today ? Date.today.strftime("%m").to_i - (@endDate.month).to_i : 12
      month_count = month_count == 0 ? 1 : 12+month_count if month_count < 1
      profits = [0]*12
      profit.each do |yearMon, sum|
        month = yearMon.split("-").last
        profits[@endDate.month - month.to_i] = sum
      end
      profits.reverse!
      profits.each_with_index {|amt, index| profits[index] = amt + profits[index -1 ] if index != 0}
      data[:data1] = profits.first(month_count)
      data[:fields] = (Array.new(12){|indx| month_name(((@endDate.month - 1 - indx) % 12) + 1).first(3)}).reverse
      expenseEntries = WkGlTransactionDetail.joins('LEFT OUTER JOIN wk_ledgers on wk_ledgers.id = wk_gl_transaction_details.ledger_id'+get_comp_cond('wk_ledgers'))
        .joins('LEFT OUTER JOIN wk_gl_transactions on wk_gl_transactions.id = wk_gl_transaction_details.gl_transaction_id'+get_comp_cond('wk_gl_transactions'))
        .where('wk_ledgers.ledger_type IN (?) and wk_gl_transactions.trans_date between ? and ?', expenseLedgerTypes, getToDateTime(@startDate), getToDateTime(@endDate))
        .select(getDatePart('wk_gl_transactions.trans_date','year','trans_year'), getDatePart('wk_gl_transactions.trans_date','month','trans_month'),+
          'SUM(wk_gl_transaction_details.amount) AS sum_amount, wk_ledgers.id as ledger_id, wk_ledgers.ledger_type, wk_gl_transaction_details.detail_type')
        .group(getDatePart('wk_gl_transactions.trans_date','year'), getDatePart('wk_gl_transactions.trans_date','month'),+
          'wk_ledgers.id, wk_ledgers.ledger_type, wk_gl_transaction_details.detail_type')
        .order('trans_year, trans_month')

      expense = Hash.new
      expenseEntries.each do |ic|
        tmonth = ic.trans_month.to_i
        if expense[tmonth].blank?
          expense[tmonth] = {ic.ledger_type => {ic.detail_type => ic.sum_amount}}
        elsif expense[tmonth][ic.ledger_type].blank?
          expense[tmonth][ic.ledger_type] = {ic.detail_type => ic.sum_amount}
        elsif expense[tmonth][ic.ledger_type][ic.detail_type].blank?
          expense[tmonth][ic.ledger_type][ic.detail_type] = ic.sum_amount
        else
          expense[tmonth][ic.ledger_type][ic.detail_type] += ic.sum_amount
        end
      end

      eProfits = Hash.new
      expense.each do |yearMon, ledTypeHash|
        ledTypeHash.each do |ledgerType, trxAmountHash|
          total = calculateBalance({ledgerType=> trxAmountHash['c'].to_f}, {ledgerType=> trxAmountHash['d'].to_f}, ledgerType)
          eProfits[yearMon] ||= 0
          eProfits[yearMon] += (total[ledgerType].to_f).round(2)
        end
      end
      expenses = [0]*12
      eProfits.each {|month, sum| expenses[@endDate.month - month.to_i] = sum }
      expenses.reverse!
      expenses.each_with_index {|amt, index| expenses[index] = (amt + expenses[index -1 ]).round(2) if index != 0}
      data[:data2] = expenses.first(month_count)
      return data
    end

    def get_detail_report(param={})
      profits = getProfits(param[:to])
      data = []
      profits.each do |yearMon, amount|
        yearMon = yearMon.split("-")
        data << {date: Date.new(yearMon.first.to_i,yearMon.last.to_i,1), amount: amount}
      end
      header = {date: l(:label_date), profit: l(:label_monthly) +" "+ l(:label_profit)}
      return {header: header, data: data}
    end

    private

    def getProfits(to)
      if to.month < getFinancialStart.to_i
        @startDate = ('01/'+getFinancialStart.to_s+'/'+(to.year - 1).to_s).to_date
        @endDate = ('01/'+getFinancialStart.to_s+'/'+(to.year).to_s).to_date - 1.second
      else
        @startDate = ('01/'+getFinancialStart.to_s+'/'+to.year.to_s).to_date
        @endDate = ('01/'+getFinancialStart.to_s+'/'+(to.year + 1).to_s).to_date - 1.second
      end
      entries = WkGlTransactionDetail.joins('LEFT OUTER JOIN wk_ledgers AS l on l.id = wk_gl_transaction_details.ledger_id'+get_comp_cond('l'))
        .joins('LEFT OUTER JOIN wk_gl_transactions AS gl on gl.id = wk_gl_transaction_details.gl_transaction_id'+get_comp_cond('gl') )
        .where('l.ledger_type IN (?) and gl.trans_date between ? and ?', incomeLedgerTypes, getToDateTime(@startDate), getToDateTime(@endDate))
        .group(getDatePart('gl.trans_date','year'), getDatePart('gl.trans_date','month'), +'l.id, l.ledger_type, wk_gl_transaction_details.detail_type')
        .order('trans_year, trans_month')
        .select(getDatePart('gl.trans_date','year','trans_year'), getDatePart('gl.trans_date','month','trans_month'),+
          'SUM(wk_gl_transaction_details.amount) AS sum_amount, l.id as ledger_id, l.ledger_type, wk_gl_transaction_details.detail_type')

      income = Hash.new
      entries.each do |ic|
        transDt = ic.trans_year.to_s + "-" + ic.trans_month.to_s
        if income[transDt].blank?
          income[transDt] = {ic.ledger_type => {ic.detail_type => ic.sum_amount}}
        elsif income[transDt][ic.ledger_type].blank?
          income[transDt][ic.ledger_type] = {ic.detail_type => ic.sum_amount}
        elsif income[transDt][ic.ledger_type][ic.detail_type].blank?
          income[transDt][ic.ledger_type][ic.detail_type] = ic.sum_amount
        else
          income[transDt][ic.ledger_type][ic.detail_type] += ic.sum_amount
        end
      end

      profit = Hash.new
      income.each do |yearMon, type|
        type.each do |ledgerType, trxAmountHash|
          total = calculateBalance({ ledgerType => trxAmountHash['c'].to_f}, { ledgerType => trxAmountHash['d'].to_f}, ledgerType)
          profit[yearMon] ||= 0
          profit[yearMon] += (total[ledgerType].to_f).round(2)
        end
      end
      return profit
    end
  end
end