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

class WkdevicesController < WkbaseController
  menu_item :wkcrmenumeration
  before_action :require_login
  before_action :check_perm_and_redirect, only: [:index, :update, :destroy]
  skip_before_action :verify_authenticity_token, only: [:check]
  accept_api_auth :check

  VALID_STATUSES = %w[new approved rejected].freeze

  def check
    unless User.current.logged?
      render json: { status: 'unauthorized' }, status: :unauthorized
      return
    end

    begin
      device = WkDevice.check_device(User.current.id, params[:device_id], {
        brand: params[:brand],
        model: params[:model],
        os_version: params[:os_version],
        app_version: params[:app_version]
      })
    rescue ActiveRecord::ActiveRecordError, ArgumentError => e
      # Never let the mobile-facing endpoint raise a 500/error page on bad input.
      logger.warn("wkdevices#check rejected invalid device data: #{e.message}")
      render json: { status: 'error', error: l(:error_invalid_device_data) }, status: :unprocessable_entity
      return
    end

    if device.approved?
      render json: { status: 'approved' }
    elsif device.rejected?
      payload = { status: 'rejected' }
      payload[:reject_reason] = l(:label_wk_single_device_denied) if device.single_device_denied
      render json: payload
    else
      render json: { status: 'new' }
    end
  end

  def index
    set_filter_session
    getUsersAndGroups
    @status = getSession(:status) || 'new'
    group_id = getSession(:group_id)
    user_id = getSession(:user_id)

    devices = WkDevice.includes(:user)

    if @status.present? && @status != 'all'
      devices = devices.where(status: WkDevice.statuses[@status])
    end
    devices = devices.where(user_id: User.in_group(group_id).select(:id)) if group_id.present? && group_id != '0'
    devices = devices.where(user_id: user_id) if user_id.present? && user_id != '0'

    devices = devices.order(last_login_at: :desc)

    @entry_count = devices.count
    setLimitAndOffset()
    @devices = devices.limit(@limit).offset(@offset)
  end

  def update
    @device = WkDevice.find(params[:id])
    new_status = params[:status]

    unless VALID_STATUSES.include?(new_status)
      flash[:error] = l(:error_invalid_status)
      redirect_to wkdevices_path(tab: 'wkdevices') and return
    end

    case new_status
    when 'approved' then @device.approve
    when 'rejected' then @device.reject
    else @device.status = new_status
    end

    if @device.save
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = l(:error_device_update_failed)
    end
    redirect_to wkdevices_path(tab: 'wkdevices')
  end

  def destroy
    @device = WkDevice.find(params[:id])
    user = @device.user
    if @device.destroy
      reset_api_key(user)
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:error_device_delete_failed)
    end
    redirect_to wkdevices_path(tab: 'wkdevices')
  end

  private

  # Same filter-session pattern as the other list pages (leave request, users):
  # filters live in session[controller_name]; the view submits searchlist so
  # set_filter_session (wkbase) picks them up, and clear=true resets them.
  def set_filter_session
    super([:status, :group_id, :user_id])
  end

  # Group / member dropdown data, following wkattendance#get_group_members.
  # Deliberately NOT WkpayrollHelper#get_group_members: that variant also applies
  # params[:status] as a User-status filter, which clashes with this page's
  # device-status filter param.
  def getUsersAndGroups
    group_id = params[:group_id].presence || getSession(:group_id)
    if group_id.present? && group_id.to_i > 0
      userList = User.in_group(group_id)
    else
      userList = User.where(type: "User").order("#{User.table_name}.firstname ASC,#{User.table_name}.lastname ASC")
    end
    @groups = Group.where(type: "Group").sorted.all
    @members = filterByAccessibleLocation(userList).collect { |user| [user.name, user.id.to_s] }
  end

  def setLimitAndOffset
    if api_request?
      @offset, @limit = api_offset_and_limit
      @limit = params[:limit] unless params[:limit].blank?
      @offset = params[:offset] unless params[:offset].blank?
    else
      @entry_pages = Paginator.new @entry_count, per_page_option, params['page']
      @limit = @entry_pages.per_page
      @offset = @entry_pages.offset
    end
  end

  def check_perm_and_redirect
    unless User.current.admin? || validateERPPermission('A_DEVICE')
      render_403
      return false
    end
  end

  def reset_api_key(user)
    if user.api_token
      user.api_token.destroy
      user.reload
    end
    user.api_key
  end
end
