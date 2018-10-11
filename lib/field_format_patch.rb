require 'uri'

module Redmine
  module FieldFormat
    class ErpFormat < RecordList
      self.searchable_supported = true

      def possible_values_options(custom_field, object=nil)
        possible_values_records(custom_field, object).map {|u| [u.name, u.id.to_s]}
      end

      def possible_values_records(custom_field, object=nil)
        target_class.select("name, id").all.order('name ASC')
      end

      def cast_single_value(view, custom_field, value, customized=nil)

      end

      def value_from_keyword(custom_field, keyword)
        parse_keyword(custom_field, keyword) do |k|
          target_class.where("LOWER(name) LIKE LOWER(?)", k).first.try(:id)
        end
      end

      def logger
        Rails.logger
      end

      def formatted_custom_value(view, custom_value, html=true)
        formatted_value(view, custom_value.custom_field, custom_value.value, custom_value.customized, true)
      end

      def dict_for_link_from_id(id)
        {}
      end

      def formatted_value(view, custom_field, value, customized=nil, html=true)
        if html
          unless value.nil?
            links = []
            unless value.is_a?(Array)
              unless value.eql? ""
                links << cast_single_value(view, custom_field, value)
              end
            else
              value.each do |single_value|
                if single_value.present?
                  links << cast_single_value(view, custom_field, single_value)
                end
              end
            end
            links.join(', ').html_safe

          end
        end
      end

    end

    class CompanyFormat < ErpFormat
      add 'company'
      self.form_partial = 'wkfieldformat/company'

      def label
        "label_wkcrmaccount_field"
      end

      def target_class
        @target_class ||= WkAccount
      end

      def dict_for_link_from_id(id)
        {:controller => "wkcrmaccount", :action => 'edit', :account_id => id}
      end

      def cast_single_value(view, custom_field, value, customized=nil)
        if value.present?
          unless value.eql? "deleted"
            account = target_class.find_by_id(value.to_i)
            unless account.nil?
              view.link_to(account.name, dict_for_link_from_id(value))
            end
          else
            l(:label_account_deleted)
          end
        end
      end

    end

    class LeadFormat < ErpFormat
      add 'wk_lead'
      self.form_partial = 'wkfieldformat/lead'

      def label
        "label_wkcrmlead_field"
      end

      def cast_single_value(view, custom_field, value, customized=nil)
        if value.present?
          unless value.eql? "deleted"
            lead = target_class.find_by_id(value.to_i)
            unless lead.nil?
              contact = WkCrmContact.find_by_id(lead.contact_id)
              unless contact.nil?
                name = contact.first_name + ' ' + contact.last_name
                view.link_to(name, dict_for_link_from_id(value))
              end
            end
          else
            l(:label_lead_deleted)
          end
        end
      end

      def possible_values_options(custom_field, object=nil)
        possible_values_records(custom_field, object).map {|u| [u.first_name + ' ' + u.last_name, u.id.to_s]}
      end

      def possible_values_records(custom_field, object=nil)
        target_class.joins("INNER JOIN wk_crm_contacts ON wk_crm_contacts.id = wk_leads.contact_id").select("wk_crm_contacts.first_name, wk_crm_contacts.last_name, wk_leads.id").all()
      end

      def target_class
        @target_class ||= WkLead
      end

      def value_from_keyword(custom_field, keyword)
        parse_keyword(custom_field, keyword) do |k|
          target_class.joins("INNER JOIN wk_crm_contacts ON wk_crm_contacts.id = wk_leads.contact_id AND LOWER(CONCAT_WS(' ', wk_crm_contacts.first_name, wk_crm_contacts.last_name)) LIKE ", "LOWER('"+ k + "')").first.try(:id)
        end
      end

      def dict_for_link_from_id(id)
        {:controller => "wklead", :action => 'edit', :lead_id => id}
      end
    end

    class CrmContactFormat < ErpFormat
      add 'crm_contact'
      self.form_partial = 'wkfieldformat/crm_contact'

      def label
        "label_wkcrmcontact_field"
      end

      def cast_single_value(view, custom_field, value, customized=nil)
        contact = target_class.find_by_id(value.to_i)
        unless value.eql? "deleted"
          unless contact.nil?
            name = contact.first_name + ' ' +contact.last_name
            view.link_to(name, dict_for_link_from_id(value))
          end
        else
          l(:label_contact_deleted)
        end
      end

      def possible_values_options(custom_field, object=nil)
        possible_values_records(custom_field, object).map {|u| [u.first_name + ' ' + u.last_name + insert_company(u.acc_name), u.id.to_s]}
      end

      def possible_values_records(custom_field, object=nil)
        target_class.joins("INNER JOIN wk_accounts ON wk_accounts.id = wk_crm_contacts.account_id").select("wk_crm_contacts.first_name, wk_crm_contacts.last_name, wk_crm_contacts.id", "wk_accounts.name AS acc_name").where("wk_crm_contacts.account_id is not null").order("first_name ASC, last_name ASC")
      end

      def insert_company(name)
        if name.present?
          ' ('+ name +')'
        else
          ''
        end
      end

      def target_class
        @target_class ||= WkCrmContact
      end

      def value_from_keyword(custom_field, keyword)
        parse_keyword(custom_field, keyword) do |k|
          target_class.where("LOWER(CONCAT_WS(' ', first_name, last_name)) LIKE LOWER(?)", k).first.try(:id)
        end
      end

      def dict_for_link_from_id(id)
        {:controller => "wkcrmcontact", :action => 'edit', :contact_id => id}
      end
    end

  end

end
