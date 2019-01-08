# ERPmine - ERP for service industry
# Copyright (C) 2011-2016  Adhi software pvt ltd
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

class WkledgerController < WkaccountingController
  unloadable
  before_filter :check_ac_admin_and_redirect, :only => [:update, :destroy]
  before_filter :check_perm_and_redirect, :only => [:index, :edit]
  include WkaccountingHelper


    def index
		set_filter_session
		ledgerType = session[:wkledger][:ledger_type]
		name = session[:wkledger][:ledger_name]
		if !ledgerType.blank? && !name.blank?
			ledger = WkLedger.where(:ledger_type => ledgerType).where("name like ?", "%#{name}%")
		end
		if !ledgerType.blank? && name.blank?
			ledger = WkLedger.where(:ledger_type => ledgerType)
		end
		if ledgerType.blank? && !name.blank?
			ledger = WkLedger.where("name like ?", "%#{name}%")
		end
		if ledgerType.blank? && name.blank?
			ledger = WkLedger.all
		end
		formPagination(ledger)
		@ledgerdd = @ledgers.pluck(:name, :id)
		@totalAmt = @ledgers.sum(:opening_balance)
    end
	
	def edit
		@ledgersDetail = WkLedger.where(:id => params[:ledger_id].to_i)
	end
	
	def update
		wkledger = nil
		errorMsg = nil
		unless params[:ledger_id].blank?
			wkledger = WkLedger.find(params[:ledger_id].to_i)
		else
			wkledger = WkLedger.new
		end
		wkledger.name = params[:name]
		wkledger.ledger_type = params[:ledger_type] unless params[:ledger_type].blank?
		wkledger.currency = Setting.plugin_redmine_wktime['wktime_currency'] 
		wkledger.opening_balance = params[:opening_balance].blank? ? 0 : params[:opening_balance]
		wkledger.owner = wkledger.ledger_type =='SY' ? 's' : 'u'
		unless wkledger.save()
			errorMsg = wkledger.errors.full_messages.join("<br>")
		end
		if errorMsg.nil?
		    redirect_to :controller => 'wkledger',:action => 'index' , :tab => 'wkledger'
		    flash[:notice] = l(:notice_successful_update)
		else
			flash[:error] = errorMsg 
		    redirect_to :controller => 'wkledger',:action => 'edit'
		end
	end
	
	def destroy
		ledger = WkLedger.find(params[:ledger_id].to_i)
		if ledger.ledger_type == 'SY'
			flash[:error] = l(:error_system_ledger_cant_delete)
	    elsif ledger.destroy
			flash[:notice] = l(:notice_successful_delete)
		else
			flash[:error] = l(:error_ledger_trans_associate)
		end
		redirect_back_or_default :action => 'index', :tab => params[:tab]
	end
	
	def set_filter_session
		if params[:searchlist].blank? && session[:wkledger].nil?
			session[:wkledger] = {:ledger_type =>	params[:ledger_type], :name => params[:name]}
		elsif params[:searchlist] =='wkledger'
			session[:wkledger][:ledger_type] = params[:ledger_type]
			session[:wkledger][:ledger_name] = params[:name]
		end

	end
	
	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@ledgers = entries.order(:id).limit(@limit).offset(@offset)
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

end
