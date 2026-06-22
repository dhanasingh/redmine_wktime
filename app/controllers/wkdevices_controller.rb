class WkdevicesController < WkbaseController
  menu_item :wkcrmenumeration
  before_action :require_login
  before_action :check_perm_and_redirect, only: [:index, :update, :destroy]
  skip_before_action :verify_authenticity_token, only: [:check]
  accept_api_auth :check

  VALID_STATUSES = %w[pending approved rejected].freeze

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
      render json: { status: 'rejected' }
    else
      render json: { status: 'pending' }
    end
  end

  def index
    if params[:clear]
      redirect_to wkdevices_path and return
    end

    @status = params[:status] || 'pending'
    @devices = WkDevice.includes(:user)

    if @status.present? && @status != 'all'
      @devices = @devices.where(status: WkDevice.statuses[@status])
    end

    @devices = @devices.order(last_login_at: :desc)
  end

  def update
    @device = WkDevice.find(params[:id])
    new_status = params[:status]
    filter_status = params[:filter_status].presence || 'pending'

    unless VALID_STATUSES.include?(new_status)
      flash[:error] = l(:error_invalid_status)
      redirect_to wkdevices_path(status: filter_status) and return
    end

    if @device.update(status: new_status)
      flash[:notice] = l(:notice_successful_update)
    else
      flash[:error] = l(:error_device_update_failed)
    end
    redirect_to wkdevices_path(status: filter_status)
  end

  def destroy
    @device = WkDevice.find(params[:id])
    filter_status = params[:filter_status].presence || 'pending'
    user = @device.user
    if @device.destroy
      reset_api_key(user)
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:error_device_delete_failed)
    end
    redirect_to wkdevices_path(status: filter_status)
  end

  private

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
