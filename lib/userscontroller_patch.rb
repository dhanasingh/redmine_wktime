module UsersControllerPatch
	def self.included(base)
		base.class_eval do
		
			def create
				@user = User.new(:language => Setting.default_language, :mail_notification => Setting.default_notification_option, :admin => false)
				@user.safe_attributes = params[:user]
				@user.password, @user.password_confirmation = params[:user][:password], params[:user][:password_confirmation] unless @user.auth_source_id
				@user.pref.safe_attributes = params[:pref]
				
				if @user.save
					Mailer.deliver_account_information(@user, @user.password).deliver if params[:send_information]
		
	# ============= ERPmine_patch Redmine 4.0  =====================	
					#Below code for save wk users
					erpmineUserSave
	# =======================================				
					respond_to do |format|
						format.html {
							flash[:notice] = l(:notice_user_successful_create, :id => view_context.link_to(@user.login, user_path(@user)))
							if params[:continue]
								attrs = {:generate_password => @user.generate_password}
								redirect_to new_user_path(:user => attrs)
							else
								redirect_to edit_user_path(@user)
							end
						}
						format.api  { render :action => 'show', :status => :created, :location => user_url(@user) }
					end
				else
					@auth_sources = AuthSource.all
					# Clear password input
					@user.password = @user.password_confirmation = nil

					respond_to do |format|
						format.html { render :action => 'new' }
						format.api  { render_validation_errors(@user) }
					end
				end
			end
			
			def update
				if params[:user][:password].present? && (@user.auth_source_id.nil? || 	params[:user][:auth_source_id].blank?)
					@user.password, @user.password_confirmation = params[:user][:password], params[:user][:password_confirmation]
				end
				@user.safe_attributes = params[:user]
				# Was the account actived ? (do it before User#save clears the change)
				was_activated = (@user.status_change == [User::STATUS_REGISTERED, User::STATUS_ACTIVE])
				# TODO: Similar to My#account
				@user.pref.safe_attributes = params[:pref]
				
				if @user.save
					@user.pref.save
					
	# ============= ERPmine_patch Redmine 4.0  =====================
					#Below code for save wk users
					erpmineUserSave
	# ==============================				
					if was_activated
						Mailer.deliver_account_activated(@user)
					elsif @user.active? && params[:send_information] && @user != User.current
						Mailer.deliver_account_information(@user, @user.password)
					end

					respond_to do |format|
						format.html {
							flash[:notice] = l(:notice_successful_update)
							redirect_to_referer_or edit_user_path(@user)
						}
						format.api  { render_api_ok }
					end
				else
					@auth_sources = AuthSource.all
					@membership ||= Member.new
					# Clear password input
					@user.password = @user.password_confirmation = nil

					respond_to do |format|
						format.html { render :action => :edit }
						format.api  { render_validation_errors(@user) }
					end
				end				
			end
	
	# ============= ERPmine_patch Redmine 4.0  =====================
			def erpmineUserSave
				@user.erpmineuser.safe_attributes = params[:erpmineuser]
				@user.erpmineuser.address_id = updateAddress
				if @user.erpmineuser.new_record?
					@user.erpmineuser.created_by_user_id = User.current.id
				end
				@user.erpmineuser.updated_by_user_id = User.current.id
				@user.erpmineuser.save
			end
			
			def updateAddress
				wkAddress = nil
				addressId = nil
				if params[:address_id].blank? || params[:address_id].to_i == 0
					wkAddress = WkAddress.new 
				else
					wkAddress = WkAddress.find(params[:address_id].to_i)
				end
				# For Address table
				wkAddress.address1 = params[:address1]
				wkAddress.address2 = params[:address2]
				wkAddress.work_phone = params[:work_phone]
				wkAddress.city = params[:city]
				wkAddress.state = params[:state]
				wkAddress.pin = params[:pin]
				wkAddress.country = params[:country]
				wkAddress.fax = params[:fax]
				wkAddress.mobile = params[:mobile]
				wkAddress.email = params[:email]
				wkAddress.website = params[:website]
				wkAddress.department = params[:department]
				if wkAddress.valid?
					wkAddress.save
					addressId = wkAddress.id
				end		
				addressId
			end
	# ===============================================		
		end
	end
end