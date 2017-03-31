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

class WkpaymentController < WkbillingController
  unloadable



    def index
		@payment_entries = nil
		sqlwhere = ""
		set_filter_session
		retrieve_date_range
		filter_type = session[:payment][:polymorphic_filter]
		contact_id = session[:payment][:contact_id]
		account_id = session[:payment][:account_id]
		
				
		if filter_type == '2' && !contact_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.parent_id = '#{contact_id}'  and wk_payments.parent_type = 'WkCrmContact'  "
		elsif filter_type == '2' && contact_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.parent_type = 'WkCrmContact'  "
		end
		
		if filter_type == '3' && !account_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.parent_id = '#{account_id}'  and wk_payments.parent_type = 'WkAccount'  "
		elsif filter_type == '3' && account_id.blank?
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.parent_type = 'WkAccount'  "
		end
		
		if !@from.blank? && !@to.blank?			
			sqlwhere = sqlwhere + " and "  unless sqlwhere.blank?
			sqlwhere = sqlwhere + " wk_payments.payment_date between '#{@from}' and '#{@to}'  "
		end
		
		if filter_type == '1' 
			entries = WkPayment.includes(:payment_items).where(sqlwhere)
		else
			entries = WkPayment.includes(:payment_items).where(sqlwhere)
		end	
		formPagination(entries)	
		@totalPayAmt = @payment_entries.sum("wk_payment_items.amount")
    end
	
	def edit
	end
  
    def set_filter_session
        if params[:searchlist].blank? && session[:payment].nil?
			session[:payment] = {:period_type => params[:period_type],:period => params[:period], :contact_id => params[:contact_id], :account_id => params[:account_id], :polymorphic_filter =>  params[:polymorphic_filter], :from => @from, :to => @to }
		elsif params[:searchlist] =='payment'
			session[:payment][:period_type] = params[:period_type]
			session[:payment][:period] = params[:period]
			session[:payment][:from] = params[:from]
			session[:payment][:to] = params[:to]
			session[:payment][:contact_id] = params[:contact_id]
			session[:payment][:account_id] = params[:account_id]
			session[:payment][:polymorphic_filter] = params[:polymorphic_filter]
		end
		
    end
	
	def setLimitAndOffset		
		if api_request?
			@offset, @limit = api_offset_and_limit
			if !params[:limit].blank?
				@limit = params[:limit]
			end
			if !params[:offset].blank?
				@offset = params[:offset]
			end
		else
			@entry_pages = Paginator.new @entry_count, per_page_option, params['page']
			@limit = @entry_pages.per_page
			@offset = @entry_pages.offset
		end	
	end
	
	
    def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@payment_entries = entries.limit(@limit).offset(@offset)
	end
	
	# Retrieves the date range based on predefined ranges or specific from/to param dates
	def retrieve_date_range
		@free_period = false
		@from, @to = nil, nil
		period_type = session[:payment][:period_type]
		period = session[:payment][:period]
		fromdate = session[:payment][:from]
		todate = session[:payment][:to]
		
		if (period_type == '1' || (period_type.nil? && !period.nil?)) 
		    case period.to_s
			  when 'today'
				@from = @to = Date.today
			  when 'yesterday'
				@from = @to = Date.today - 1
			  when 'current_week'
				@from = getStartDay(Date.today - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when 'last_week'
				@from =getStartDay(Date.today - 7 - (Date.today.cwday - 1)%7)
				@to = @from + 6
			  when '7_days'
				@from = Date.today - 7
				@to = Date.today
			  when 'current_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1)
				@to = (@from >> 1) - 1
			  when 'last_month'
				@from = Date.civil(Date.today.year, Date.today.month, 1) << 1
				@to = (@from >> 1) - 1
			  when '30_days'
				@from = Date.today - 30
				@to = Date.today
			  when 'current_year'
				@from = Date.civil(Date.today.year, 1, 1)
				@to = Date.civil(Date.today.year, 12, 31)
	        end
		elsif period_type == '2' || (period_type.nil? && (!fromdate.nil? || !todate.nil?))
		    begin; @from = fromdate.to_s.to_date unless fromdate.blank?; rescue; end
		    begin; @to = todate.to_s.to_date unless todate.blank?; rescue; end
		    @free_period = true
		else
		  # default
		  # 'current_month'		
			@from = Date.civil(Date.today.year, Date.today.month, 1)
			@to = (@from >> 1) - 1
	    end    
		
		@from, @to = @to, @from if @from && @to && @from > @to

	end

end
