module SendPatch::ImportPatch
  def self.included(base)
    base.class_eval do

      def run(options={})
        max_items = options[:max_items]
        max_time = options[:max_time]
        current = 0
        imported = 0
        resume_after = items.maximum(:position) || 0
        interrupted = false
        started_on = Time.now

        read_items do |row, position|
          if (max_items && imported >= max_items) || (max_time && Time.now >= started_on + max_time)
            interrupted = true
            break
          end
          if position > resume_after
            item = items.build
            item.position = position
            item.unique_id = row_value(row, 'unique_id') if use_unique_id?

            if object = build_object(row, item)
              # ======= ERPmine_patch Redmine 6.1 ==========
              if type == 'TimeEntryImport'
                wktime_helper = Object.new.extend(WktimeHelper)
                errorMsg = wktime_helper.statusValidation(object)
                if errorMsg.blank? && object.save
                  spentForModel = wktime_helper.saveSpentFor(nil, nil, nil, object.id, object.class.name, (object.spent_on).to_date, '00', '00', nil)
                  item.obj_id = object.id
                else
                  item.message = errorMsg + object.errors.full_messages.join("\n")
                end
              else
                if object.save
                  item.obj_id = object.id
                  else
                  item.message = object.errors.full_messages.join("\n")
                  end
              end
              # =============================
            end

            item.save!
            imported += 1

            extend_object(row, item, object) if object.persisted?
            do_callbacks(use_unique_id? ? item.unique_id : item.position, object)
          end
          current = position
        end

        if imported == 0 || interrupted == false
          if total_items.nil?
            update_attribute :total_items, current
          end
          update_attribute :finished, true
          remove_file
        end

        current
      end

    end
  end
end