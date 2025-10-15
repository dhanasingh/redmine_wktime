module SendPatch::ApplicationHelperPatch
  def self.included(base)
    base.class_eval do
      def format_object(object, *args, &block)
        options =
          if args.first.is_a?(Hash)
            args.first
          elsif !args.empty?
            # Support the old syntax `format_object(object, html_flag)`
            # TODO: Display a deprecation warning in a future version, then remove this
            {:html => args.first}
          else
            {}
          end

        html = options.fetch(:html, true)
        thousands_delimiter = options.fetch(:thousands_delimiter, false)
        delimiter_char = thousands_delimiter ? ::I18n.t('number.format.delimiter') : nil

        if block
          object = yield object
        end
        case object
        when Array
          formatted_objects = object.map do |o|
            format_object(o, html: html, thousands_delimiter: thousands_delimiter)
          end
          html ? safe_join(formatted_objects, ', ') : formatted_objects.join(', ')
        when Time, ActiveSupport::TimeWithZone
          format_time(object)
        when Date
          format_date(object)
        when Integer
          number_with_delimiter(object, delimiter: delimiter_char)
        when Float
          number_with_delimiter(sprintf('%.2f', object), delimiter: delimiter_char)
        when User, Group
          html ? link_to_principal(object) : object.to_s
        when Project
          html ? link_to_project(object) : object.to_s
        when Version
          html ? link_to_version(object) : object.to_s
        when TrueClass
          l(:general_text_Yes)
        when FalseClass
          l(:general_text_No)
        when Issue
          object.visible? && html ? link_to_issue(object) : "##{object.id}"
        when Attachment
          if html
            content_tag(
              :span,
              link_to_attachment(object) +
              link_to_attachment(
                object,
                :class => ['icon-only', 'icon-download'],
                :title => l(:button_download),
                :download => true
              )
            )
          else
            object.filename
          end
          # ============= ERPmine_patch Redmine 6.1  =====================
        when WkInventoryItem
          brandName = object.product_item.brand.blank? ? "" : object.product_item.brand.name
          modelName = object.product_item.product_model.blank? ? "" : object.product_item.product_model.name
          str = "#{object.product_item.product.name} - #{brandName} - #{modelName}"
          assetObj = object.asset_property
          str = str + ' - ' +assetObj.name if object&.product_type != 'I'
          str
        # =============================
        when CustomValue, CustomFieldValue
          return "" unless object.customized&.visible?

          if object.custom_field
            f = object.custom_field.format.formatted_custom_value(self, object, html)
            if f.nil? || f.is_a?(String)
              f
            else
              format_object(f, html: html, thousands_delimiter: object.custom_field.thousands_delimiter?, &block)
            end
          else
            object.value.to_s
          end
        else
          html ? h(object) : object.to_s
        end
      end
    end
  end
end