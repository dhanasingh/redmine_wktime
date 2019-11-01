class WkdocumentController < WkbaseController
  unloadable
  before_action :find_attachment, :only => [:destroy, :download]
  include WkdocumentHelper
  helper :attachments
  
  def new
  end

  def save
    errMsg = ''
    if params[:attachments].present?
      params[:attachments].each do |atch_param|
        attachment = Attachment.find_by_token(atch_param[1][:token])
        next if attachment.blank?
        attachment.container_type = params[:container_type]
        attachment.container_id = params[:container_id]
        attachment.filename = attachment.filename
        attachment.description = atch_param[1][:description]
        attachment.save
        unless attachment.save
          errMsg += attachment.errors.full_messages.to_s
        end
      end
    else
      errMsg = l(:error_invalid_document)
    end
    if errMsg.blank?
		  redirect_to getRedirectUrl(params[:container_id], params[:container_type])
      flash[:notice] = l(:notice_successful_update)
    else
			flash[:error] = errMsg
      redirect_to action: 'new', container_type: params[:container_type], container_id: params[:container_id]
    end
  end

  def download
    if !(validateERPPermission("B_CRM_PRVLG") || validateERPPermission("A_CRM_PRVLG"))
      render_403
    else
      @attachment.increment_download
      send_file @attachment.diskfile, :filename => filename_for_content_disposition(@attachment.filename),
                                      :type => detect_content_type(@attachment),
                                      :disposition => disposition(@attachment) if stale?(:etag => @attachment.digest)
    end
  end

  def destroy
    if validateERPPermission("A_CRM_PRVLG")
      container_id = @attachment.container_id
      container_type = @attachment.container_type
      if @attachment.destroy
        flash[:notice] = l(:notice_successful_delete)
      else
        flash[:error] = account.errors.full_messages.join("<br>")
      end
      redirect_to getRedirectUrl(container_id, container_type)
    else
      render_403
    end
  end

  def find_attachment
    @attachment = Attachment.where(id: params[:id]).first
    render_404 if @attachment.blank?
  end

  def detect_content_type(attachment)
    content_type = attachment.content_type
    if content_type.blank? || content_type == "application/octet-stream"
      content_type = Redmine::MimeType.of(attachment.filename)
    end
    content_type.to_s
  end
  
  def disposition(attachment)
    if attachment.is_pdf?
      'inline'
    else
      'attachment'
    end
  end
end