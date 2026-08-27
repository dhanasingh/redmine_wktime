# ERPmine - ERP for service industry
# Copyright (C) 2011-  Adhi software pvt ltd
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

class WkexchangerateController < WkbillingController

  menu_item :wkcrmenumeration

	def index
		entries = WkExCurrencyRate.all
		formPagination(entries)
	end

	def update
		arrId = WkExCurrencyRate.all.pluck(:id)
		for i in 0..params[:exrate_id].length-1
			if params[:exrate_id][i].blank?
				curExchanges = WkExCurrencyRate.new
			else
				curExchanges = WkExCurrencyRate.find(params[:exrate_id][i].to_i)
				arrId.delete(params[:exrate_id][i].to_i)
			end
			curExchanges.from_c = params[:from_currency][i]
			curExchanges.to_c = params[:to_currency][i]
			curExchanges.ex_rate = params[:rate][i]
			curExchanges.save()
		end

		if !arrId.blank?
			WkExCurrencyRate.where(:id => arrId).delete_all
		end

		redirect_to :controller => 'wkexchangerate',:action => 'index' , :tab => 'wkexchangerate'
		flash[:notice] = l(:notice_successful_update)
	end

	def formPagination(entries)
		@entry_count = entries.count
        setLimitAndOffset()
		@curentry = entries.limit(@limit).offset(@offset)
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
