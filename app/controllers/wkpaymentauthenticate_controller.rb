class WkpaymentauthenticateController < ApplicationController
  skip_before_action :check_if_login_required
  protect_from_forgery with: :exception

  include WkcaptchaHelper
  include WkpgHelper

  def index
    clear_payment_session
    @invoice_number = params[:invoice_number]
    @invoice_date = params[:invoice_date]
    generate_captcha
  end

  def send_code
    invoice_number = params[:invoice_number].to_s.strip
    invoice_date = params[:invoice_date].to_s.strip

    # CAPTCHA validation
    unless valid_captcha?(params[:captcha_answer])
      flash[:error] = l(:error_invalid_captcha)
      redirect_to payment_path(invoice_number: invoice_number, invoice_date: invoice_date)
      return
    end
    
    # Validation
    if invoice_number.blank? || invoice_date.blank?
      flash[:error] = l(:error_enter_invoice_details)
      redirect_to payment_path(invoice_number: invoice_number, invoice_date: invoice_date)
      return
    end

    # Find Invoice
    invoice = WkInvoice.find_by(invoice_number: invoice_number, invoice_date: invoice_date)
    
    if invoice.blank?
      flash[:error] = l(:error_invalid_information)
      redirect_to payment_path
      return
    end

    # Check if invoice is already paid
    if invoice.status != 'o'
      flash[:error] = l(:error_invoice_already_paid)
      redirect_to payment_path
      return
    end

    # Get Parent (Account or Contact)
    parent = invoice.parent
    if parent.blank?
      flash[:error] = l(:error_invalid_information)
      redirect_to payment_path
      return
    end

    # Get Email from Parent's Address
    address = parent.respond_to?(:address) ? parent.address : nil
    email = address&.email

    if email.blank?
      # Don't reveal that no email exists - redirect to verify page with flag
      session[:otp_not_sent] = true
      redirect_to payment_verify_path
      return
    end

    email = email.to_s.strip.downcase

    # IP-based Rate Limit Check (prevent distributed attacks)
    if WkAuthCode.where(ip_address: request.remote_ip, created_at: 1.hour.ago..Time.current).count >= 10
      flash[:error] = l(:error_too_many_requests_from_ip)
      redirect_to payment_path
      return
    end

    # Email-based Rate Limit Check
    if WkAuthCode.where(type_value: email, created_at: 1.hour.ago..Time.current).count >= 3
      flash[:error] = l(:error_too_many_verification_requests)
      redirect_to payment_path
      return
    end

    # Invalidate any existing unverified tokens for this email
    WkAuthCode.where(type_value: email, is_verified: false)
                  .where('expires_at > ?', Time.current)
                  .update_all(expires_at: Time.current)

    # Generate 6-digit code by merging two 3-digit ROTP codes
    first_half = ROTP::TOTP.new(ROTP::Base32.random, digits: 3).now
    second_half = ROTP::TOTP.new(ROTP::Base32.random, digits: 3).now
    code = "#{first_half}#{second_half}"

    # Log in Database
    log = WkAuthCode.create(
      type_value: email,
      code: code,
      parent_type: invoice.class.name,
      parent_id: invoice.id,
      ip_address: request.remote_ip,
      expires_at: 10.minutes.from_now,
      attempts: 0,
      is_verified: false
    )

    # For logged-in users, preserve Redmine session; for guests, full reset
    if User.current.logged?
      clear_payment_session
    else
      reset_session
    end
    session[:payment_verification_id] = log.id
    session[:payment_verification_email] = email

    # Send email
    begin
      WkMailer.send_verification_code(email, code).deliver_now
      redirect_to payment_verify_path
    rescue => e
      Rails.logger.error "Failed to send verification email: #{e.message}"
      flash[:error] = l(:error_sending_email)
      redirect_to payment_path
    end
  end

  def verify_page
    @email = session[:payment_verification_email]
    @otp_not_sent = session[:otp_not_sent] || false
    redirect_to payment_path if @email.blank? && !@otp_not_sent
  end

  def verify
    email = session[:payment_verification_email]
    entered_code = params[:verification_code]
    log_id = session[:payment_verification_id]

    if email.blank?
      redirect_to payment_path
      return
    end

    # 1. Find the Log Record
    log = WkAuthCode.find_by(id: log_id)

    if log.blank? || log.type_value != email
      flash[:error] = l(:error_verification_session_invalid)
      redirect_to payment_path
      return
    end

    # 2. Check Expiry
    if Time.current > log.expires_at
      session[:payment_verification_id] = nil
      flash[:error] = l(:error_verification_expired)
      redirect_to payment_path
      return
    end

    # 3. Check Attempt Limit (Max 3 attempts)
    if log.attempts >= 3
      session[:payment_verification_id] = nil
      flash[:error] = l(:error_verification_max_attempts)
      redirect_to payment_path
      return
    end

    # 4. Verify Code
    if !ActiveSupport::SecurityUtils.secure_compare(log.code, entered_code.to_s.strip)
      # Increment failed attempts
      log.increment!(:attempts)
      
      flash[:error] = l(:error_invalid_verification_code_attempts, count: (3 - log.attempts))
      redirect_to payment_verify_path
      return
    end

    # Success
    log.update(is_verified: true, verified_at: Time.current)
    session[:payment_verified_email] = email
    session[:payment_verified_at] = Time.current
    session[:payment_verified_ip] = request.remote_ip
    session[:payment_verification_id] = nil
    session[:otp_verified] = true
    
    redirect_to payment_invoices_path
  end

  def invoices
    return unless verify_payment_session!

    # Verify nonce — proves user came through the OTP flow
    unless session[:otp_verified].present?
      clear_payment_session
      flash[:error] = l(:error_session_expired)
      redirect_to payment_path
      return
    end

    # Consume nonce (single-use)
    session.delete(:otp_verified)

    verified_email = session[:payment_verified_email]

    # Find the most recent verified log for this email
    last_log = WkAuthCode.where(type_value: verified_email, is_verified: true)
                                    .order(verified_at: :desc).first
    
    if last_log
      # Auth code's parent is the verified invoice — get the invoice's parent (account/contact)
      verified_invoice = last_log.parent
      if verified_invoice
        # Find all open invoices for the same account/contact
        invoice_types = ['I', 'SI']
        @pending_invoices = WkInvoice.where(
          parent_type: verified_invoice.parent_type,
          parent_id: verified_invoice.parent_id,
          invoice_type: invoice_types,
          status: 'o'
        ).order(invoice_date: :asc)
      else
        @pending_invoices = WkInvoice.none
      end
                                  
      if @pending_invoices.empty?
        flash.now[:warning] = l(:error_no_pending_invoices)
      end
    else
      # Fallback logic if log is missing (shouldn't happen)
      redirect_to payment_path
    end
  end

  def process_payment
    return unless verify_payment_session!

    verified_email = session[:payment_verified_email]

    # Get selected invoice IDs
    invoice_ids = params[:invoice_ids]
    if invoice_ids.blank?
      flash[:error] = l(:error_no_invoices_selected)
      redirect_to payment_invoices_path
      return
    end

    # Store invoice IDs in session for gateway controllers
    session[:pg_invoice_ids] = invoice_ids

    # Get the verified log to get parent info
    last_log = WkAuthCode.where(type_value: verified_email, is_verified: true)
                             .order(verified_at: :desc).first
    
    unless last_log
      flash[:error] = l(:error_verification_session_invalid)
      redirect_to payment_path
      return
    end

    # Auth code's parent is the verified invoice — get the invoice's parent (account/contact)
    verified_invoice = last_log.parent
    unless verified_invoice
      flash[:error] = l(:error_verification_session_invalid)
      redirect_to payment_path
      return
    end

    # Fetch selected invoices and validate they belong to the same account/contact
    invoices = WkInvoice.where(
      id: invoice_ids,
      parent_type: verified_invoice.parent_type,
      parent_id: verified_invoice.parent_id,
      status: 'o'
    )

    if invoices.empty?
      flash[:error] = l(:error_invalid_invoices)
      redirect_to payment_path
      return
    end

    # Check if a payment is already in progress for selected invoices
    update_pgpay_timeout(invoice_ids)
    if pgpay_exists?(invoice_ids)
      flash[:error] = l(:error_payment_already_processing)
      redirect_to payment_path
      return
    end

    # Get currency from the first invoice item
    currency = invoices.first.invoice_items.first&.original_currency
    if currency.blank?
      flash[:error] = l(:error_currency_not_found)
      redirect_to payment_invoices_path
      return
    end

    # Determine gateway type and redirect
    currency_code = get_currency_code(currency)
    
    case currency_code
    when 'INR'
      redirect_to wkpg_ccavenue_process_payment_path(invoice_ids: invoice_ids)
    else
      redirect_to wkpg_paypal_process_payment_path(invoice_ids: invoice_ids)
    end
  end

  private

  # Centralized session validation with IP binding
  def verify_payment_session!
    verified_email = session[:payment_verified_email]
    verified_at = session[:payment_verified_at]
    verified_ip = session[:payment_verified_ip]
    
    # Check existence and timeout (30 minutes)
    unless verified_email.present? && 
           verified_at.present? && 
           Time.current <= verified_at + 30.minutes
      clear_payment_session
      flash[:error] = l(:error_session_expired) if verified_at.present?
      redirect_to payment_path
      return false
    end
    
    # IP binding check - prevent session hijacking
    if verified_ip.present? && verified_ip != request.remote_ip
      clear_payment_session
      flash[:error] = l(:error_session_ip_mismatch)
      redirect_to payment_path
      return false
    end
    
    true
  end

  # Clear all payment-related session data
  def clear_payment_session
    session.delete(:payment_verified_email)
    session.delete(:payment_verified_at)
    session.delete(:payment_verified_ip)
    session.delete(:payment_verification_id)
    session.delete(:payment_verification_email)
    session.delete(:pg_invoice_ids)
    session.delete(:pg_payment_id)
    session.delete(:captcha_answer)
    session.delete(:otp_not_sent)
    session.delete(:otp_verified)
  end
end
