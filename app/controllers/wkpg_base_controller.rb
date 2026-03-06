# Base controller for payment gateway operations
# Provides shared functionality for CCAvenue and PayPal controllers

class WkpgBaseController < ApplicationController
  skip_before_action :check_if_login_required
  protect_from_forgery with: :exception, except: [:response_handler, :redirect_handler]

  include WkpgHelper
  include WkgltransactionHelper

  before_action :validate_session, only: [:process_payment]

  protected

  # Session validation for public payment flow
  def validate_session
    @verified_email = session[:payment_verified_email]
    @verified_at = session[:payment_verified_at]

    if @verified_email.blank? || @verified_at.blank? || Time.current > @verified_at + 30.minutes
      clear_payment_session
      flash[:error] = l(:error_session_expired)
      redirect_to payment_path
      return false
    end

    # Get the verified log for parent info
    @auth_log = WkAuthCode.where(type_value: @verified_email, is_verified: true)
                              .order(verified_at: :desc).first

    unless @auth_log
      flash[:error] = l(:error_verification_session_invalid)
      redirect_to payment_path
      return false
    end

    true
  end

  # Load payment gateway configuration from plugin settings
  def config_setup(adapter)
    settings = Setting.plugin_redmine_wktime
    @brand = settings['wktime_brand_name'].presence || 'ERPmine'
    
    (settings['wktime_pg_config'] || []).each do |item|
      elements = (item || '').split('|')
      next unless elements[0].to_s.upcase == adapter.upcase

      @merchant_id = elements[2].to_s.strip
      @working_key = elements[3].to_s.strip
      @access_code = elements[4].to_s.strip
      @redirect_url = elements[5].to_s.strip
      @cancel_url = elements[6].to_s.strip
      @adapter_url = elements[7].to_s.strip
      break
    end
  end

  # Get billing address from parent (Account or Contact)
  def get_billing_address(parent)
    return {} unless parent

    address = parent.addresses.first if parent.respond_to?(:addresses)
    
    {
      name: get_parent_name(parent),
      phone: address&.phone.to_s.gsub(/\D/, '').presence || '',
      email: address&.email.to_s.strip.presence || @verified_email,
      country: address&.country.to_s.presence || '',
      country_code: get_country_code(address&.country),
      state: address&.state.to_s.presence || '',
      state_code: address&.state.to_s.presence || '',
      city: address&.city.to_s.slice(0, 30).presence || '',
      address1: address&.address1.to_s.slice(0, 150).presence || '',
      address2: address&.address2.to_s.slice(0, 150).presence || '',
      pin: address&.pin.to_s.presence || ''
    }
  end

  # Get parent name (Account or Contact)
  def get_parent_name(parent)
    if parent.respond_to?(:name)
      parent.name.to_s
    elsif parent.respond_to?(:first_name)
      [parent.first_name, parent.last_name].compact.join(' ')
    else
      ''
    end
  end

  # Get ISO country code
  def get_country_code(country)
    return '' unless country.present?
    # Simple mapping - in production, use a proper country code library
    country.to_s.upcase.slice(0, 2)
  end

  # Common pre-flight validation for payment processing
  # Returns [pg_payment, invoice_ids] on success, or redirects and returns nil on failure
  def prepare_payment
    @invoices = get_selected_invoices

    if @invoices.blank?
      flash[:error] = l(:error_no_invoices_selected)
      redirect_to payment_invoices_path
      return nil
    end

    invoice_ids = @invoices.pluck(:id)
    update_pgpay_timeout(invoice_ids)

    if pgpay_exists?(invoice_ids)
      flash[:error] = l(:error_payment_already_processing)
      redirect_to payment_invoices_path
      return nil
    end

    verified_invoice = @auth_log.parent
    pg_payment = initiate_pg_payment(@invoices, verified_invoice.class.name, verified_invoice.id)

    session[:pg_payment_id] = pg_payment.id
    session[:pg_invoice_ids] = invoice_ids

    [pg_payment, invoice_ids]
  end

  # Initiate payment gateway transaction
  def initiate_pg_payment(invoices, parent_type, parent_id)
    total_amount = invoices.sum(&:total_invoice_amount)
    original_currency = invoices.first.invoice_items.first&.original_currency || '₹'
    to_currency = Setting.plugin_redmine_wktime['wktime_currency']

    pg_items_attributes = invoices.map do |invoice|
      org_amount = invoice.total_invoice_amount
      inv_currency = invoice.invoice_items.first&.original_currency || original_currency
      exchanged_amount = getExchangedAmount(inv_currency, org_amount)

      {
        invoice_id: invoice.id,
        amount: exchanged_amount,
        currency: to_currency,
        original_amount: org_amount,
        original_currency: inv_currency
      }
    end

    exchanged_total = getExchangedAmount(original_currency, total_amount)

    pg_payment = WkPgPayment.new(
      status: WkPgPayment::STATUS_INITIATED,
      amount: exchanged_total,
      currency: to_currency,
      original_amount: total_amount,
      original_currency: original_currency,
      parent_type: parent_type,
      parent_id: parent_id,
      wk_pg_payment_items_attributes: pg_items_attributes
    )

    pg_payment.save!
    pg_payment
  end

  # Create actual payment record after successful gateway transaction
  # Follows the same pattern as WkpaymententityController#update and updatePaymentItem helper
  def create_payment(pg_payment)
    return [false, l(:error_pg_payment_not_found)] unless pg_payment
    return [false, l(:error_payment_not_successful)] unless pg_payment.successful?

    pg_items = pg_payment.wk_pg_payment_items
    to_currency = Setting.plugin_redmine_wktime['wktime_currency']
    result = [false, 'Unknown error']

    ActiveRecord::Base.transaction do
      parent = pg_payment.parent
      parent_name = get_parent_name(parent)

      inv_numbers = pg_items.map { |item| "##{item.wk_invoice&.invoice_number}" }.join(', ')
      total_original_currency = pg_payment.original_currency.to_s
      total_original_amount = format('%.2f', pg_payment.original_amount)

      # pg_payment's parent is the verified invoice; WkPayment needs the invoice's parent (Account/Contact)
      verified_inv = pg_payment.parent
      invoice_parent = verified_inv.parent
      payment = WkPayment.new
      payment.parent_type = invoice_parent.class.name
      payment.parent_id = invoice_parent.id
      payment.payment_date = pg_payment.pg_trans_date&.to_date || Date.current
      payment.payment_type_id = Setting.plugin_redmine_wktime['wktime_pg_payment_type_id'].presence&.to_i ||
                                WkCrmEnumeration.where(enum_type: 'PT').order(:position, :name).first&.id
      payment.reference_number = pg_payment.pg_id
      payment.description = "AccName:#{parent_name} InvNo:#{inv_numbers} PaymentAmt:#{total_original_currency}#{total_original_amount}"

      unless payment.save
        error_msg = payment.errors.full_messages.join(', ')
        Rails.logger.error "create_payment: WkPayment save failed - #{error_msg}"
        result = [false, error_msg]
        raise ActiveRecord::Rollback
      end

      # Create WkPaymentItem records individually (matching updatePaymentItem helper pattern)
      pg_items.each do |pg_item|
        pay_item = payment.payment_items.new
        pay_item.payment_id = payment.id
        pay_item.invoice_id = pg_item.invoice_id
        pay_item.is_deleted = false
        pay_item.original_amount = pg_item.original_amount
        pay_item.original_currency = pg_item.original_currency
        pay_item.currency = to_currency
        pay_item.amount = getExchangedAmount(pg_item.original_currency, pg_item.original_amount)
        pay_item.save!
      end

      # Link pg_payment to actual payment
      pg_payment.update!(wk_payment_id: payment.id)

      # Update invoice statuses to closed
      pg_items.each { |pg_item| pg_item.wk_invoice&.update!(status: 'c') }

      Rails.logger.info "Payment created successfully: ID=#{payment.id}, PG_ID=#{pg_payment.pg_id}"
      result = [true, l(:notice_payment_successful)]
    end

    result
  rescue StandardError => e
    Rails.logger.error "Failed to create payment: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    [false, e.message]
  end

  # Clear all payment-related session data
  def clear_payment_session
    session.delete(:payment_verified_email)
    session.delete(:payment_verified_at)
    session.delete(:payment_verified_ip)
    session.delete(:payment_verification_id)
    session.delete(:payment_verification_email)
    session.delete(:pg_payment_id)
    session.delete(:pg_invoice_ids)
    session.delete(:captcha_answer)
    session.delete(:otp_not_sent)
    session.delete(:otp_verified)
  end

  # Get invoices from session or params
  def get_selected_invoices
    invoice_ids = params[:invoice_ids] || session[:pg_invoice_ids]
    return nil if invoice_ids.blank?

    # Ensure invoice_ids is an array
    invoice_ids = [invoice_ids] unless invoice_ids.is_a?(Array)

    # Auth code's parent is the verified invoice — get account/contact from it
    verified_invoice = @auth_log.parent
    return nil unless verified_invoice

    # Validate invoices belong to the same account/contact
    WkInvoice.where(
      id: invoice_ids,
      parent_type: verified_invoice.parent_type,
      parent_id: verified_invoice.parent_id,
      status: 'o'
    )
  end
end
