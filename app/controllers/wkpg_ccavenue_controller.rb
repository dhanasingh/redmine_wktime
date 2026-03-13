# CCAvenue Payment Gateway Controller
# Handles payment processing via CCAvenue for INR transactions

class WkpgCcavenueController < WkpgBaseController
  before_action -> { config_setup('CCAVENUE') }, only: [:process_payment, :response_handler, :redirect_handler]

  # Process payment - encrypt data and redirect to CCAvenue
  def process_payment
    # Common pre-flight: validate invoices, check pending, initiate pg_payment
    result = prepare_payment
    return unless result

    @pg_payment, invoice_ids = result

    # Validate gateway configuration
    unless @adapter_url.present? && @access_code.present? && @merchant_id.present? && @working_key.present?
      flash[:error] = l(:label_pg_config_missing)
      redirect_to payment_invoices_path
      return
    end

    begin
      # Create security token for response validation
      @token = Token.new(user_id: 0, action: 'wkpg_token')
      @token.save!

      # Get billing address from the account/contact
      verified_invoice = @auth_log.parent
      parent = verified_invoice.parent
      addr = get_billing_address(parent)
      pg_currency = get_currency_code(@pg_payment.currency)

      request_data = {
        'merchant_id' => @merchant_id,
        'order_id' => @pg_payment.id.to_s,
        'amount' => format('%.2f', @pg_payment.amount),
        'currency' => pg_currency,
        'redirect_url' => @redirect_url,
        'cancel_url' => @cancel_url,
        'language' => 'EN',
        'billing_name' => addr[:name].to_s.slice(0, 100),
        'billing_address' => addr[:address1].to_s.slice(0, 150),
        'billing_city' => addr[:city].to_s.slice(0, 30),
        'billing_state' => addr[:state].to_s.slice(0, 30),
        'billing_zip' => addr[:pin].to_s.slice(0, 10),
        'billing_country' => addr[:country].to_s.slice(0, 50),
        'billing_tel' => addr[:phone].to_s.slice(0, 20),
        'billing_email' => addr[:email].to_s.slice(0, 100),
        'merchant_param1' => invoice_ids.join(','),
        'merchant_param2' => @token.value,
        'merchant_param3' => verified_invoice.parent_type,
        'merchant_param4' => verified_invoice.parent_id.to_s
      }

      # Save request data for audit
      @pg_payment.update!(pg_request: request_data.to_json, updated_by_id: User.current.logged? ? User.current.id : nil)

      # Build query string and encrypt
      merchant_data = request_data.map { |k, v| "#{k}=#{v}" }.join('&')
      @encrypted_data = encrypt(merchant_data, @working_key)

      render 'process_payment'

    rescue StandardError => e
      Rails.logger.error "CCAvenue process_payment error: #{e.message}"
      flash[:error] = l(:error_create_order_failed) + e.message
      redirect_to payment_invoices_path
    end
  end

  # Handle CCAvenue response (POST callback from gateway)
  def response_handler
    error = nil

    begin
      enc_response = params[:encResp]
      
      if enc_response.blank?
        error = l(:error_data_missing)
      else
        # Decrypt response
        decrypted_response = decrypt(enc_response, @working_key)
        
        # Parse response to hash
        response_data = {}
        decrypted_response.split('&').each do |pair|
          key, value = pair.split('=', 2)
          response_data[key] = value if key.present?
        end

        # Verify security token
        token = Token.find_by(action: 'wkpg_token', value: response_data['merchant_param2'])
        
        if token && response_data['merchant_param2'] == token.value
          # Delete token to prevent replay attacks
          Token.where(action: 'wkpg_token', value: response_data['merchant_param2']).delete_all

          # Find payment gateway record
          pg_payment = WkPgPayment.find_by(id: response_data['order_id'])
          
          if pg_payment
            # Update payment record with response
            pg_payment.pg_id = response_data['tracking_id']
            pg_payment.status = get_payment_status(response_data['order_status'])
            pg_payment.pg_msg = response_data['status_message']
            pg_payment.pg_pay_method = response_data['payment_mode']
            pg_payment.pg_trans_date = parse_trans_date(response_data['trans_date'])
            pg_payment.pg_response = response_data.to_json
            pg_payment.updated_by_id = User.current.id if User.current.logged?

            if pg_payment.save
              redirect_to wkpg_ccavenue_redirect_handler_path(id: pg_payment.id)
              return
            else
              error = pg_payment.errors.full_messages.join(', ')
            end
          else
            error = l(:error_payment_response_not_found, order_id: response_data['order_id'])
          end
        else
          error = l(:error_invalid_auth_token)
          Rails.logger.warn "CCAvenue token validation failed for order: #{response_data['order_id']}"
        end
      end

    rescue StandardError => e
      error = e.message || l(:notice_payment_res_failed)
      Rails.logger.error "CCAvenue response_handler error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    if error.present?
      Rails.logger.error "CCAvenue payment error: #{error}"
      flash[:error] = error
      redirect_to payment_invoices_path
    end
  end

  # Handle payment result - create actual payment record on success
  def redirect_handler
    error = nil

    begin
      pg_payment = WkPgPayment.find_by(id: params[:id], wk_payment_id: nil)

      if pg_payment.present? && pg_payment.successful?
        success, message = create_payment(pg_payment)
        
        if success
          flash[:notice] = message
          clear_payment_session
          redirect_to payment_path
          return
        else
          error = message
        end
      else
        error = pg_payment&.pg_msg || l(:notice_payment_processed)
      end

    rescue StandardError => e
      error = e.message
      Rails.logger.error "CCAvenue redirect_handler error: #{e.message}"
    end

    if error.present?
      Rails.logger.error error
      flash[:error] = error
    end

    # Clear session and redirect to start page (not invoices, to avoid nonce conflict)
    clear_payment_session
    redirect_to payment_path
  end

  private

  # AES-128-CBC encryption (CCAvenue format)
  def encrypt(plain_text, key)
    secret_key = [Digest::MD5.hexdigest(key)].pack('H*')
    cipher = OpenSSL::Cipher.new('aes-128-cbc')
    cipher.encrypt
    cipher.key = secret_key
    cipher.iv = (0..15).to_a.pack('C*')
    encrypted = cipher.update(plain_text) + cipher.final
    encrypted.unpack1('H*')
  end

  # AES-128-CBC decryption (CCAvenue format)
  def decrypt(cipher_text, key)
    secret_key = [Digest::MD5.hexdigest(key)].pack('H*')
    encrypted_data = [cipher_text].pack('H*')
    decipher = OpenSSL::Cipher.new('aes-128-cbc')
    decipher.decrypt
    decipher.key = secret_key
    decipher.iv = (0..15).to_a.pack('C*')
    decrypted = decipher.update(encrypted_data) + decipher.final
    decrypted.gsub(/\0+$/, '')  # Remove null padding
  rescue OpenSSL::Cipher::CipherError => e
    Rails.logger.error "CCAvenue decryption failed: #{e.message}"
    nil
  end

  # Parse transaction date from CCAvenue format
  def parse_trans_date(date_str)
    return nil if date_str.blank?
    DateTime.parse(date_str)
  rescue ArgumentError
    nil
  end
end
