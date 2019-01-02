class WkdashboardController < WkbaseController
# TODO - Make compactible with redmine 4.0
before_action :require_login

require 'SVG/Graph/Bar'
require 'SVG/Graph/BarHorizontal'
require 'SVG/Graph/Pie'
require 'SVG/Graph/Line'
require 'SVG/Graph/Plot'
require 'yaml'
include WkdashboardHelper 
# require 'SVG/Graph/Bar'
# require 'SVG/Graph/BarHorizontal'
# require 'SVG/Graph/Pie'
# require 'SVG/Graph/Line'
# require 'SVG/Graph/Plot'

include WkcrmHelper
include WktimeHelper

  def index
	if Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].blank? ||
	   Setting.plugin_redmine_wktime['wktime_enable_dashboards_module'].to_i == 0
	   redirect_to :controller => 'wktime',:action => 'index' , :tab => 'wktime'
	else
	  set_filter_session
	  setMembers
	  retrieve_date_range
    end	
  end
  
  def graph
	retrieve_date_range
     graph_yml_data= YAML.load(ERB.new(File.read("#{Rails.root}/#{params[:gPath]}")).result).first   
     graph_datas = eval(graph_yml_data[1]['code_str'])    
     graph = get_graphs(graph_yml_data[1]['chart_type'], graph_datas['fields'], graph_yml_data[0],label_check(graph_yml_data[1]['x_title']), label_check(graph_yml_data[1]['y_title'])) 
    
     graph_yml_data[1]['names_of_data'].each do |data_name|
        graph.add_data(:data => eval(data_name['data']) , :title => label_check(data_name['title']))
     end
    
     data = graph.burn  
    
    # data = nil
	# @group_id = session[:wkdashboard][:group_id]
    # @project_id = session[:wkdashboard][:project_id]
    # case params[:graph]
    # when "clock_in_users_over_time"
      # data = graph_clock_in_users_over_time
	# when "expense_for_issues"
      # data = graph_expense_for_issues
    # when "lead_generation_vs_conversion"
      # data = graph_lead_generation_vs_conversion
    # when "invoice_vs_payment_per_month"
      # data = graph_invoice_vs_payment_per_month
	# when "assests_per_month"
      # data = graph_assests_per_month
	# when "profit_loss_per_month"
	  # data = graph_profit_loss_per_month
    # end

    if data
      headers["Content-Type"] = params[:type]
      send_data(data, :type => "image/svg+xml", :disposition => "inline")
    else
      render_404
    end
  end
  
	
  def get_graphs(graphType, fields, graphTitle, xTitle, yTitle)	
	graph = SVG::Graph.const_get(graphType).new(
      :height => 230,
      :width => 330,
      :fields => fields,
      :stack => :side,
      :scale_integers => true,
      :step_x_labels => 2,
      :show_data_values => false,
      :graph_title => graphTitle,
      :show_graph_title => true,
	  :show_x_title => true,
      :x_title => (graphType == "Pie" ? "" : xTitle),
      :show_y_title => true,
      :y_title_text_direction => :bt,
      :y_title => (graphType == "Pie" ? "" : yTitle),
	  :key => (graphType == "Pie" ? false : true),
	  :key_position => :bottom,
	  :show_data_labels =>  true,
	  :show_actual_values => true,
      :show_percent => false,
	  :datapoint_font_size => 10,
      :title_font_size => 14,
      :x_label_font_size => 8,
      :x_title_font_size => 12,
      :y_label_font_size => 8,
      :y_title_font_size => 12,
      :key_font_size => 8
    )
	graph
  end  
  
  # def graph_clock_in_users_over_time
	# @date_to = User.current.today# - 4.days
    # @date_from = @date_to.at_beginning_of_day()
	# @date_to = @date_to.at_end_of_day()
    # @date_from = Date.civil(@date_from.year, @date_from.month, 1)
    # clock_in_of_user = WkAttendance.
      # where("start_time BETWEEN ? AND ?", @date_to.at_beginning_of_day().utc, @date_to.utc).select("user_id, min(start_time) as clock_in").group(:user_id)
    # clock_in_per_time = [0] * 24
    # clock_in_of_user.each {|c| clock_in_per_time[c.clock_in.at_end_of_hour.hour] += 1 }
	
    # fields = []
    # today = User.current.today
    # 24.times {|m| fields << m}

	# graph = get_graphs("Bar", fields, l(:label_clock_in_users_over_time), l(:label_hours), l(:label_no_of_employees))
	
	
    # graph.add_data(
      # :data => clock_in_per_time[0..23],
      # :title => l(:label_no_of_employees)
    # )

    # graph.burn
  # end
  
  # def graph_expense_for_issues
    # @current_date = User.current.today
    # # @date_from = @date_to << 11
    # # @date_from = Date.civil(@date_from.year, @date_from.month, 1)
    # expense_for_issues = WkExpenseEntry.
	  # where("spent_on BETWEEN ? AND ?", @current_date.at_beginning_of_month(), @current_date.at_end_of_month()).select("issue_id, sum(amount) as total_amount").group(:issue_id)
    # #expense_for_issues_by_month = [0] * 12
    # issue_expense_hash = expense_for_issues.map {|c| [c.issue.subject,c.total_amount] }.to_h
    # fields = issue_expense_hash.keys.sort
	# issue_expense_arr = Array.new
	# fields.each {|c| issue_expense_arr << issue_expense_hash[c]}
    # #today = User.current.today
    # #12.times {|m| fields << month_name(((today.month - 1 - m) % 12) + 1)}

	# graph = get_graphs("Pie", fields, l(:label_expense_for_issues), l(:label_hours), (:label_days))

    # graph.add_data(
      # :data => issue_expense_arr[0..(fields.length - 1)],
      # :title => l(:label_total_expense_of_issues)
    # )

    # graph.burn
  # end

  # def graph_lead_generation_vs_conversion
	# @date_to = User.current.today
    # @date_from = @date_to << 11
    # @date_from = Date.civil(@date_from.year, @date_from.month, 1)
	
    # createdLeadList = WkLead.joins(:contact).where(:created_at => getFromDateTime(@date_from) .. getToDateTime(@date_to))
	
	# convertedLeadList = WkLead.joins(:contact).where(:status_update_on => getFromDateTime(@date_from) .. getToDateTime(@date_to), :status => 'C')
	
	# createdLeadCounts = createdLeadList.select("extract(month from wk_leads.created_at) as month_val, count(extract(month from wk_leads.created_at)) created_count").group("extract(month from wk_leads.created_at)")
	
	# covertedLeadCounts = convertedLeadList.select("extract(month from wk_leads.status_update_on) as month_val, count(extract(month from wk_leads.status_update_on)) as convert_count").group("extract(month from wk_leads.status_update_on)")
	
    # lead_creation_hash = createdLeadCounts.map {|c| [c.month_val.to_s,c.created_count] }.to_h
	# fields = []
	# 12.times {|m| fields << month_name(((@date_to.month - 1 - m) % 12) + 1).first(3)}
	
	# lead_creation_arr = [0]*12
    # lead_creation_hash.each {|month, count| lead_creation_arr[@date_to.month - month.to_i] = count }
	
	# lead_conversation_hash = covertedLeadCounts.map {|c| [c.month_val.to_s,c.convert_count] }.to_h
	# lead_conversation_arr = [0]*12
	# lead_conversation_hash.each {|month, count| lead_conversation_arr[@date_to.month - month.to_i] = count}
	
	# graph = get_graphs("Line", fields, l(:label_lead_generation_vs_conversion), l(:label_months), l(:label_no_of_leads))
	
    # graph.add_data(
      # :data => lead_creation_arr.reverse,
      # :title => l(:label_created_lead)
    # )
	
	# graph.add_data(
      # :data => lead_conversation_arr.reverse,
      # :title => l(:label_converted_lead)
    # )

    # graph.burn
  # end 

  # def graph_invoice_vs_payment_per_month
	# @date_to = User.current.today
    # @date_from = @date_to << 11
    # @date_from = Date.civil(@date_from.year, @date_from.month, 1)
	
    # invoiceList = WkInvoice.joins(:invoice_items).where(:invoice_date => getFromDateTime(@date_from) .. getToDateTime(@date_to))
	
	# paymentList = WkPayment.joins(:payment_items).where(:payment_date => getFromDateTime(@date_from) .. getToDateTime(@date_to))
	
	# toalInvoiceAmount = invoiceList.select("extract(month from wk_invoices.invoice_date) as month_val, sum(wk_invoice_items.amount) invoice_total").group("extract(month from wk_invoices.invoice_date)")
	
	# toalPayment = paymentList.select("extract(month from wk_payments.payment_date) as month_val, sum(wk_payment_items.amount) payment_total").group("extract(month from wk_payments.payment_date)")
	
    # invoice_total_hash = toalInvoiceAmount.map {|c| [c.month_val.to_s,c.invoice_total.to_i] }.to_h
	# fields = []
	# 12.times {|m| fields << month_name(((@date_to.month - 1 - m) % 12) + 1).first(3)}
	# invoice_total_arr = [0]*12
    # invoice_total_hash.each {|month, sum| invoice_total_arr[@date_to.month - month.to_i] = sum }
	# invoice_total_arr.reverse!
	# invoice_total_arr.each_with_index {|amt, index| invoice_total_arr[index] = amt + invoice_total_arr[index -1 ] if index != 0}
	# invoice_total_arr.reverse!
	
	# payment_total_hash = toalPayment.map {|c| [c.month_val.to_s,c.payment_total.to_i] }.to_h
	# fields = []
	# 12.times {|m| fields << month_name(((@date_to.month - 1 - m) % 12) + 1).first(3)}
	# payment_total_arr = [0]*12
    # payment_total_hash.each {|month, sum| payment_total_arr[@date_to.month - month.to_i] = sum }
	# payment_total_arr.reverse!
	# payment_total_arr.each_with_index {|amt, index| payment_total_arr[index] = amt + payment_total_arr[index -1 ] if index != 0}
	# payment_total_arr.reverse!
	
    # graph = get_graphs("Line", fields, l(:label_invoice_vs_payment_per_month), l(:label_months), l(:label_amount))
	
    # graph.add_data(
      # :data => invoice_total_arr.reverse,
      # :title => l(:label_total_invoice)
    # )
	
	# graph.add_data(
      # :data => payment_total_arr.reverse,
      # :title => l(:label_total_payment)
    # )

    # graph.burn
  # end  
 
  # def graph_assests_per_month
    # @date_to = User.current.today + 1.year
    # @date_from = @date_to << 11
    # @date_from = Date.civil(@date_from.year, @date_from.month, 1)
    # asset_value_by_month = WkAssetDepreciation.
	# where("depreciation_date BETWEEN ? AND ?", @date_from, @date_to).
	# select("extract(year from wk_asset_depreciations.depreciation_date) as year_val, extract(month from wk_asset_depreciations.depreciation_date) as month_val, sum(actual_amount) as total_amount").group("extract(year from wk_asset_depreciations.depreciation_date), extract(month from wk_asset_depreciations.depreciation_date)")
	
	# assest_value_hash = Hash.new
	# asset_value_by_month.each {|c| assest_value_hash[(c.year_val.to_s + (c.month_val.to_s.length == 1 ? "0" : "") + c.month_val.to_s).to_i] = c.total_amount }
	# yearMonthArr = assest_value_hash.keys.sort
	# fields = []
	# 12.times {|m| fields << month_name(((@date_to.month - 1 - m) % 12) + 1).first(3)} # + " " + ((((@date_to.month - 1 - m) % 12) + 1) < 1 ? @date_to.year - 1 : @date_to.year).to_s} 
	# assest_value_arr = [0]*12
	# last_year = @date_from.year
	# last_month = @date_from.month
	# last_total = 0
    # yearMonthArr.each do |yearMon|
		# year = yearMon.to_s.first(4).to_i
		# month = yearMon.to_s.last(2).to_i
		# while last_month != month && ((last_month + 1) % 12 != month) #(((last_month + 1) % 12) != month)
			# assest_value_arr[@date_to.month - ((last_month + 1) % 12)] = last_total
			# last_year += 1 #yearMon.to_s.first(4).to_i
			# last_month += 1 #yearMon.to_s.last(2).to_i
		# end
		# assest_value_arr[@date_to.month - yearMon.to_s.last(2).to_i] = assest_value_hash[yearMon]
		# last_year = year #yearMon.to_s.first(4).to_i
		# last_month = month #yearMon.to_s.last(2).to_i
		# last_total = assest_value_hash[yearMon]
	# end
	
	# graph = get_graphs("Line", fields, l(:label_assests_per_month), l(:label_months), l(:label_amount))

    # graph.add_data(
      # :data => assest_value_arr[0..11].reverse,
      # :title => l(:label_total_assests_per_month)
    # )

    # graph.burn
  # end
  
	# def graph_profit_loss_per_month
    # @date_to = User.current.today + 1.month #- 1.year
    # @date_from = @date_to << 11
    # @date_from = Date.civil(@date_from.year, @date_from.month, 1)
	
		# incomeDetail = WkGlTransactionDetail.joins("LEFT OUTER JOIN wk_ledgers on wk_ledgers.id = wk_gl_transaction_details.ledger_id").joins("LEFT OUTER JOIN wk_gl_transactions on wk_gl_transactions.id = wk_gl_transaction_details.gl_transaction_id" ).where('wk_ledgers.ledger_type IN (?) and wk_gl_transactions.trans_date between ? and ?', incomeLedgerTypes, @date_from, @date_to).select("SUM(wk_gl_transaction_details.amount) AS sum_amount, wk_ledgers.id as ledger_id, wk_ledgers.ledger_type, wk_gl_transaction_details.detail_type, extract(year from wk_gl_transactions.trans_date) AS trans_year, extract(month from wk_gl_transactions.trans_date) AS trans_month ").group('wk_ledgers.id, wk_ledgers.ledger_type, wk_gl_transaction_details.detail_type, extract(year from wk_gl_transactions.trans_date), extract(month from wk_gl_transactions.trans_date)')
	
	# incomeHash = Hash.new
	# incomeDetail.each do |ic|
		# transDt = (ic.trans_year.to_i.to_s + (ic.trans_month.to_i.to_s.length == 1 ? "0" : "") + ic.trans_month.to_i.to_s).to_i
		# if incomeHash[transDt].blank?
			# incomeHash[transDt] = {ic.ledger_type => {ic.detail_type => ic.sum_amount}}
		# else
			# if incomeHash[transDt][ic.ledger_type].blank?
				# incomeHash[transDt][ic.ledger_type] = {ic.detail_type => ic.sum_amount}
			# else
				# if incomeHash[transDt][ic.ledger_type][ic.detail_type].blank?
					# incomeHash[transDt][ic.ledger_type][ic.detail_type] = ic.sum_amount
				# else
					# incomeHash[transDt][ic.ledger_type][ic.detail_type] += ic.sum_amount
				# end				
			# end			
		# end
	# end
	
	# profitIncomeHash = Hash.new
	# incomeHash.each do |yearMon, ledTypeHash|
		# ledTypeHash.each do |ledgerType, trxAmountHash|
			# profitValHash = calculateBalance({ledgerType=> trxAmountHash['c'].to_f}, {ledgerType=> trxAmountHash['d'].to_f}, ledgerType)
			# unless profitIncomeHash[yearMon].blank?
				# profitIncomeHash[yearMon] += profitValHash[ledgerType].to_f
			# else
				# profitIncomeHash[yearMon] = profitValHash[ledgerType].to_f
			# end
		# end
	# end
	
	# fields = []
	# 12.times {|m| fields << month_name(((@date_to.month - 1 - m) % 12) + 1).first(3)}
	
	# profit_income_arr = [0]*12
    # profitIncomeHash.each {|month, sum| profit_income_arr[@date_to.month - month.to_i] = sum }
	
	# expenseDetail = WkGlTransactionDetail.joins("LEFT OUTER JOIN wk_ledgers on wk_ledgers.id = wk_gl_transaction_details.ledger_id").joins("LEFT OUTER JOIN wk_gl_transactions on wk_gl_transactions.id = wk_gl_transaction_details.gl_transaction_id" ).where('wk_ledgers.ledger_type IN (?) and wk_gl_transactions.trans_date between ? and ?', expenseLedgerTypes, @date_from, @date_to).select("SUM(wk_gl_transaction_details.amount) AS sum_amount, wk_ledgers.id as ledger_id, wk_ledgers.ledger_type, wk_gl_transaction_details.detail_type, extract(year from wk_gl_transactions.trans_date) AS trans_year, extract(month from wk_gl_transactions.trans_date) AS trans_month ").group('wk_ledgers.id, wk_ledgers.ledger_type, wk_gl_transaction_details.detail_type, extract(year from wk_gl_transactions.trans_date), extract(month from wk_gl_transactions.trans_date)')
	# expenseHash = Hash.new
	# expenseDetail.each do |ic|
		# transDt = (ic.trans_year.to_i.to_s + (ic.trans_month.to_i.to_s.length == 1 ? "0" : "") + ic.trans_month.to_i.to_s).to_i
		# if expenseHash[transDt].blank?
			# expenseHash[transDt] = {ic.ledger_type => {ic.detail_type => ic.sum_amount}}
		# else
			# if expenseHash[transDt][ic.ledger_type].blank?
				# expenseHash[transDt][ic.ledger_type] = {ic.detail_type => ic.sum_amount}
			# else
				# if expenseHash[transDt][ic.ledger_type][ic.detail_type].blank?
					# expenseHash[transDt][ic.ledger_type][ic.detail_type] = ic.sum_amount
				# else
					# expenseHash[transDt][ic.ledger_type][ic.detail_type] += ic.sum_amount
				# end				
			# end			
		# end
	# end
	
	# profitExpenseHash = Hash.new
	# expenseHash.each do |yearMon, ledTypeHash|
		# ledTypeHash.each do |ledgerType, trxAmountHash|
			# profitValHash = calculateBalance({ledgerType=> trxAmountHash['c'].to_f}, {ledgerType=> trxAmountHash['d'].to_f}, ledgerType)
			
			# unless profitExpenseHash[yearMon].blank?
				# profitExpenseHash[yearMon] += profitValHash[ledgerType].to_f
			# else
				# profitExpenseHash[yearMon] = profitValHash[ledgerType].to_f
			# end
		# end
	# end
	
	# yearMonthArr = profitExpenseHash.keys.sort
	# fields = []
	# 12.times {|m| fields << month_name(((@date_to.month - 1 - m) % 12) + 1).first(3)} # + " " + ((((@date_to.month - 1 - m) % 12) + 1) < 1 ? @date_to.year - 1 : @date_to.year).to_s} 
	# profit_expense_arr = [0]*12
	# last_year = @date_from.year
	# last_month = @date_from.month
	# last_total = 0
    # yearMonthArr.each do |yearMon|
		# year = yearMon.to_s.first(4).to_i
		# month = yearMon.to_s.last(2).to_i
		# while last_month != month && ((last_month + 1) % 12 != month) #(((last_month + 1) % 12) != month)
			# profit_expense_arr[@date_to.month - ((last_month + 1) % 12)] = last_total
			# last_year += 1 #yearMon.to_s.first(4).to_i
			# last_month += 1 #yearMon.to_s.last(2).to_i
		# end
		# profit_expense_arr[@date_to.month - yearMon.to_s.last(2).to_i] = profitExpenseHash[yearMon]
		# last_year = year #yearMon.to_s.first(4).to_i
		# last_month = month #yearMon.to_s.last(2).to_i
		# last_total = profitExpenseHash[yearMon]
	# end

	# graph = get_graphs("Line", fields, l(:label_profit_loss_per_month), l(:label_months), l(:label_amount))

    # graph.add_data(
      # :data => profit_income_arr.reverse,
      # :title => l(:label_total_income)
    # )
	
	# graph.add_data(
      # :data => profit_expense_arr.reverse,
      # :title => l(:label_total_expense)
    # )

    # graph.burn
  # end

  def set_filter_session
	if session[:wkdashboard].nil?
		session[:wkdashboard] = {:period_type => params[:period_type], :period => params[:period],:group_id => params[:group_id], :from => @from, :to => @to}
	else
		session[:wkdashboard][:project_id] = params[:project_id]
		session[:wkdashboard][:group_id] = params[:group_id]
		session[:wkdashboard][:period] = params[:period]
		session[:wkdashboard][:from] = params[:from]
		session[:wkdashboard][:to] = params[:to]
	end
  end  

  def setMembers		
	@groups = Group.sorted.all
  end		
end
