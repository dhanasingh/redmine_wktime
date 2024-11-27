# ERPmine - ERP for service industry
# Copyright (C) 2011-2020  Adhi software pvt ltd
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

class WkdocumentController < WkbaseController

  before_action :find_attachment, :only => [:destroy, :download]
  include WkdocumentHelper
  helper :attachments

  def new
  end

  def save
    errMsg = ''
    if params[:attachments].present?
      errMsg = save_attachments()
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
    @attachment.increment_download
    send_file @attachment.diskfile, :filename => filename_for_content_disposition(@attachment.filename),
                                      :type => detect_content_type(@attachment),
                                      :disposition => disposition(@attachment) if stale?(:etag => @attachment.digest)
  end

  def destroy
    container_id = @attachment.container_id
      container_type = @attachment.container_type
      if @attachment.destroy
        flash[:notice] = l(:notice_successful_delete)
      else
        flash[:error] = account.errors.full_messages.join("<br>")
      end
      redirect_to :back
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