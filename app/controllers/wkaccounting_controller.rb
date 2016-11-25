class WkaccountingController < WkbaseController	
  unloadable
	def index
	end
	
	def pl_rpt	
		#userId = session[:wkreport][:user_id].blank? ? 0 : session[:wkreport][:user_id]
		@from = session[:wkreport][:from]
		@to = session[:wkreport][:to]
		Rails.logger.info("========== from = #{@from}, @to = #{@to} ==========")
		#groupId = session[:wkreport][:group_id].blank?  ? 0 : session[:wkreport][:group_id]
		@profitLossEntries = WkTransactionDetail.includes(:ledger, :wktransaction).where('wk_ledgers.ledger_type in (?) and wk_transactions.trans_date between ? and ?', ['DI','DE','II','IE'], @from, @to).order('wk_ledgers.id').references(:ledger,:wktransaction)
		Rails.logger.info("======= @profitLossEntries = #{@profitLossEntries} =======")
		Rails.logger.info("======= @profitLossEntries.sum = #{@profitLossEntries.group('wk_ledgers.id').sum('wk_transaction_details.amount').inspect} =======")
		@sumEntries = @profitLossEntries.group('wk_ledgers.id').sum('wk_transaction_details.amount')
		@profitLossEntries.each do |entry|
			Rails.logger.info("======= entry = #{entry} =======")
			Rails.logger.info("======= entry.ledger.name = #{entry.ledger.name} =======")
			Rails.logger.info("======= entry.ledger.type = #{entry.ledger.ledger_type} =======")
			Rails.logger.info("======= entry.ledger.name = #{entry.amount} =======")
			Rails.logger.info("======= sumEntries[entry.ledger.id] = #{@sumEntries[entry.ledger.id]} =======")
		end
		render :action => 'pl_rpt', :layout => false
	end
end
