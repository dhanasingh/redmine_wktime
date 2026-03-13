# PayPal Payment Gateway Controller
# Handles payment processing via PayPal for USD and other international currencies

require 'net/http'
require 'uri'
require 'json'

class WkpgPaypalController < WkpgBaseController
  before_action -> { config_setup('PAYPAL') }, only: [:process_payment, :response_handler, :cancel_handler]

  # Process payment - create PayPal order and redirect
  def process_payment
    # Common pre-flight: validate invoices, check pending, initiate pg_payment
    result = prepare_payment
    return unless result

    @pg_payment, invoice_ids = result

    # Validate gateway configuration
    unless @adapter_url.present? && @merchant_id.present? && @access_code.present?
      flash[:error] = l(:label_pg_config_missing)
      redirect_to payment_invoices_path
      return
    end

    begin
      # Get OAuth access token
      @access_token = get_access_token
      unless @access_token
        flash[:error] = l(:error_paypal_auth_failed)
        redirect_to payment_invoices_path
        return
      end

      # Create PayPal order
      create_paypal_order(@pg_payment)

    rescue StandardError => e
      Rails.logger.error "PayPal process_payment error: #{e.message}"
      flash[:error] = l(:error_create_order_failed) + e.message
      redirect_to payment_invoices_path
    end
  end

  # Handle PayPal response (redirect callback after payment)
  def response_handler
    begin
      # Get access token for capture
      @access_token = get_access_token
      unless @access_token
        flash[:error] = l(:error_paypal_auth_failed)
        redirect_to payment_invoices_path
        return
      end

      # Capture the order
      result = capture_order(params[:token])

      if result[:success]
        response_data = result[:response]
        
        # Find pg_payment_id from custom_id in response
        pg_id = response_data.dig('purchase_units', 0, 'payments', 'captures', 0, 'custom_id') ||
                extract_custom_id(response_data)

        if pg_id.present?
          pg_payment = WkPgPayment.find_by(id: pg_id)

          if pg_payment
            # Update payment record
            pg_payment.pg_id = response_data['id']
            pg_payment.status = response_data['status'] == 'COMPLETED' ? 'SU' : 'FA'
            pg_payment.pg_msg = response_data['status']
            pg_payment.pg_pay_method = response_data.dig('payment_source')&.keys&.first
            pg_payment.pg_response = response_data.to_json
            pg_payment.pg_trans_date = response_data.dig('purchase_units', 0, 'payments', 'captures', 0, 'create_time') || Time.current
            pg_payment.updated_by_id = User.current.id if User.current.logged?

            if pg_payment.save && pg_payment.successful?
              success, message = create_payment(pg_payment)
              if success
                flash[:notice] = message
                clear_payment_session
              else
                flash[:error] = message
              end
            else
              flash[:error] = pg_payment.pg_msg || l(:error_payment_failed)
            end
          else
            flash[:error] = l(:error_payment_response_not_found, order_id: pg_id)
          end
        else
          flash[:error] = l(:error_payment_id_not_found)
        end
      else
        # Update status on failure
        pg_payment_id = session[:pg_payment_id]
        if pg_payment_id
          pg_payment = WkPgPayment.find_by(id: pg_payment_id)
          pg_payment&.mark_failed!(result[:error])
        end
        flash[:error] = result[:error] || l(:error_payment_failed)
      end

    rescue StandardError => e
      Rails.logger.error "PayPal response_handler error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:error] = e.message || l(:error_response_handler)
    end

    redirect_to payment_path
  end

  # Handle PayPal cancellation
  def cancel_handler
    begin
      pg_payment_id = session[:pg_payment_id]
      
      if pg_payment_id
        pg_payment = WkPgPayment.find_by(id: pg_payment_id)
        pg_payment&.mark_aborted!
      end

      clear_payment_session
      flash[:warning] = l(:error_payment_process_cancelled)

    rescue StandardError => e
      Rails.logger.error "PayPal cancel_handler error: #{e.message}"
      flash[:error] = e.message || l(:error_cancel_handler)
    end

    redirect_to payment_path
  end

  private

  # Get PayPal OAuth access token
  def get_access_token
    uri = URI.parse("#{@adapter_url}/v1/oauth2/token")
    request = Net::HTTP::Post.new(uri)
    request.basic_auth(@merchant_id, @access_code)
    request.set_form_data('grant_type' => 'client_credentials')

    response = make_https_request(uri, request)
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)['access_token']
    else
      Rails.logger.error "PayPal OAuth failed: #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "PayPal get_access_token error: #{e.message}"
    nil
  end

  # Create PayPal order via API
  def create_paypal_order(pg_payment)
    uri = URI.parse("#{@adapter_url}/v2/checkout/orders")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@access_token}"
    request['Content-Type'] = 'application/json'
    request.body = build_order_request(pg_payment).to_json

    response = make_https_request(uri, request)
    response_json = JSON.parse(response.body) rescue {}

    if response.is_a?(Net::HTTPSuccess)
      # Find approval URL
      approval_url = response_json['links']&.find { |l| l['rel'] == 'payer-action' }&.dig('href')

      # Save PayPal order ID
      pg_payment.update!(
        pg_id: response_json['id'],
        pg_request: response_json.to_json,
        updated_by_id: User.current.logged? ? User.current.id : nil
      )

      if approval_url.present?
        redirect_to approval_url
      else
        flash[:error] = l(:error_paypal_approval_url_missing)
        redirect_to payment_invoices_path
      end
    else
      # Log error and redirect
      Rails.logger.error "PayPal create order failed: #{response.body}"
      
      pg_payment.update!(
        pg_id: response_json['id'],
        pg_request: response_json.to_json,
        status: 'FA',
        pg_msg: response_json['message'],
        updated_by_id: User.current.logged? ? User.current.id : nil
      )

      error_details = (response_json['details'] || []).map { |d| "#{d['field']}: #{d['issue']}" }.join(', ')
      flash[:error] = [response_json['message'], error_details].compact.join(' - ')
      redirect_to payment_invoices_path
    end
  end

  # Capture PayPal order after approval
  def capture_order(order_id)
    uri = URI.parse("#{@adapter_url}/v2/checkout/orders/#{order_id}/capture")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@access_token}"
    request['Content-Type'] = 'application/json'

    response = make_https_request(uri, request)
    response_json = JSON.parse(response.body) rescue {}

    if response.is_a?(Net::HTTPSuccess) && response.code == '201'
      { success: true, response: response_json }
    else
      { success: false, error: response_json['message'] || l(:notice_payment_process_failed) }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  # Build PayPal order request body
  def build_order_request(pg_payment)
    verified_invoice = @auth_log.parent
    parent = verified_invoice.parent
    addr = get_billing_address(parent)

    {
      intent: 'CAPTURE',
      payment_source: {
        paypal: {
          experience_context: {
            brand_name: @brand,
            payment_method_preference: 'IMMEDIATE_PAYMENT_REQUIRED',
            landing_page: 'NO_PREFERENCE',
            user_action: 'PAY_NOW',
            return_url: @redirect_url,
            cancel_url: @cancel_url
          },
          email_address: addr[:email],
          name: {
            given_name: get_first_name(addr[:name]),
            surname: get_last_name(addr[:name])
          },
          phone: {
            phone_type: 'MOBILE',
            phone_number: {
              national_number: addr[:phone].presence || '0000000000'
            }
          },
          address: build_paypal_address(addr)
        }
      },
      purchase_units: [
        {
          custom_id: pg_payment.id.to_s,  # Used to identify payment on return
          description: "Invoice Payment - #{pg_payment.wk_pg_payment_items.map(&:invoice_number).compact.join(', ')}".slice(0, 127),
          amount: {
            currency_code: get_currency_code(pg_payment.original_currency),
            value: format('%.2f', pg_payment.original_amount)
          }
        }
      ]
    }
  end

  # Build PayPal address structure
  def build_paypal_address(addr)
    {
      address_line_1: addr[:address1].presence || 'N/A',
      address_line_2: addr[:address2],
      admin_area_2: addr[:city].presence || 'N/A',
      admin_area_1: addr[:state_code],
      postal_code: addr[:pin].presence || '00000',
      country_code: addr[:country_code].presence || 'US'
    }
  end

  # Extract custom_id from PayPal response (nested structure)
  def extract_custom_id(response_data)
    response_data.dig('purchase_units')
      &.flat_map { |unit| unit.dig('payments', 'captures') || [] }
      &.find { |capture| capture['custom_id'].present? }
      &.dig('custom_id')
  end

  # Make HTTPS request with SSL
  def make_https_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER  # Verify SSL certificate
    http.open_timeout = 30
    http.read_timeout = 60
    http.request(request)
  end

  # Get first name from full name
  def get_first_name(full_name)
    return '' if full_name.blank?
    parts = full_name.to_s.split(' ')
    parts.first.to_s.gsub(/[^a-zA-Z]/, '').slice(0, 140)
  end

  # Get last name from full name
  def get_last_name(full_name)
    return '' if full_name.blank?
    parts = full_name.to_s.split(' ')
    (parts.length > 1 ? parts[1..-1].join(' ') : '').gsub(/[^a-zA-Z ]/, '').slice(0, 140)
  end
end
