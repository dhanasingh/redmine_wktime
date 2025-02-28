# ERPmine - ERP for service industry
# Copyright (C) 2011-2021  Adhi software pvt ltd
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

module WkdocumentHelper

  def getDocuments
      url = getDocumentType
      tableName = Object.const_get(url[:container_type]).table_name
      @attachments = Attachment.joins("INNER JOIN #{tableName} ON #{tableName}.id = container_id
        AND container_type='#{url[:container_type]}' #{get_comp_cond(tableName)}")
        .where("#{tableName}.id = ?", url[:container_id])
  end

  def getDocumentType
      url = {controller: "wkdocument", action: "new"}
      case(controller_name)
      when "wklead", "wkreferrals"
          url[:container_type] = "WkLead"
          url[:container_id] = params[:lead_id]
      when "wkcrmaccount", "wksupplieraccount"
          url[:container_type] = "WkAccount"
          url[:container_id] = params[:account_id]
      when "wkopportunity"
          url[:container_type] = "WkOpportunity"
          url[:container_id] = params[:opp_id]
      when "wkcrmactivity"
          url[:container_type] = "WkCrmActivity"
          url[:container_id] = params[:activity_id]
      when "wkcrmcontact", "wksuppliercontact"
          url[:container_type] = "WkCrmContact"
          url[:container_id] = params[:contact_id]
      end
      call_hook(:getDocAccordionSection, {url: url, controller_name: controller_name, params: params})
      url
  end

  def getRedirectUrl(container_id, container_type)
      url = Hash.new
      call_hook(:getDocRedirectUrl, {url: url, container_id: container_id, container_type: container_type})
      case(container_type)
      when "WkLead"
        contact_type = WkLead.find(container_id).contact.contact_type
        url = {controller: contact_type == "IC" ? "wkreferrals" : "wklead", action: "edit", lead_id: container_id}
      when "WkAccount"
          url = {controller: "wkcrmaccount", action: "edit", account_id: container_id}
      when "WkOpportunity"
          url = {controller: "wkopportunity", action: "edit", opp_id: container_id}
      when "WkCrmActivity"
          url = {controller: "wkcrmactivity", action: "edit", activity_id: container_id}
      when "WkCrmContact"
          url = {controller: "wkcrmcontact", action: "edit", contact_id: container_id}
      end
      url
  end

  def delete_documents(id)
    url = getDocumentType
    attachments = Attachment.where(container_id: id,container_type: url[:container_type])
    unless attachments.delete_all
        flash[:error] = attachments.errors.full_messages.join("<br>")
    end
  end

  def save_attachments(container_id=params[:container_id], attachments=params[:attachments], container_type=params[:container_type])
    errMsg = ""
    attachments.each do |atch_param|
    attachment = Attachment.find_by_token(atch_param[1][:token])
    next if attachment.blank?
      attachment.container_type = container_type
      attachment.container_id = container_id
      attachment.filename = attachment.filename
      attachment.description = atch_param[1][:description]
      unless attachment.save
        errMsg += attachment.errors.full_messages.to_s
      end
    end
    errMsg
  end

  def attachments_links(container, options = {})
    attachments =
      if container.attachments.loaded?
        container.attachments
      else
        container.attachments.preload(:author).to_a
      end
    if attachments.any?
      options = {
        view: false,
        :editable => false,
        :deletable => false,
        :author => true,
        :download => true
      }.merge(options)

      render :partial => 'wkdocument/links',
        :locals => {
          :container => container,
          :attachments => attachments,
          :options => options,
          :thumbnails => (options[:thumbnails] && Setting.thumbnails_enabled?)
        }
    end
  end

  def location_attachment(attachment, options={})
    text = options.delete(:text) || attachment.filename
    html_options = options.slice!(:only_path, :filename)
    url = url_for(controller: "wkdocument", action: "download", id: attachment.id)
    (html_options[:editable] || html_options[:download]) ? link_to( text, url, html_options) : text
  end

  def container_attachments_edit_path(container)
    wk_object_attachments_edit_path container.class.name.underscore.pluralize, container.id
  end
end