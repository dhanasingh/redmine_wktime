class AddWkUserColumns < ActiveRecord::Migration[6.1]
    def change
      add_column :wk_users, :state_insurance, :string
      add_column :wk_users, :employee_id, :string
      add_column :wk_users, :emergency_contact, :string, limit: 50
      add_column :wk_users, :notes, :text
      add_reference :wk_users, :marital, :class => "WkCrmEnumeration"
      add_reference :wk_users, :emerg_type, :class => "WkCrmEnumeration"
      add_reference :wk_users, :dept_section, :class => "WkCrmEnumeration"

      reversible do |dir|
        if File.exist?(Rails.root+'plugins/redmine_wktime/config/config.yml')
          cols =  ['retirement_account']
          data = YAML::load_file(Rails.root+'plugins/redmine_wktime/config/config.yml')
          crypt = ActiveSupport::MessageEncryptor.new(data['encryption_key'])

          dir.up do
            change_column :wk_users, :account_number, :string, limit: 1000
            change_column :wk_users, :tax_id, :string, limit: 1000
            change_column :wk_users, :ss_id, :string, limit: 1000

            WkUser.all.each do |u|
              cols.each do |col|
                if u[col].present?
                  decryptVal = crypt.decrypt_and_verify(u[col])
                  u[col] = decryptVal
                end
              end
              u.save
            end
          end
          dir.down do
            WkUser.all.each do |u|
              cols.each do |col|
                if u[col].present?
                  encryptVal = crypt.encrypt_and_sign(u[col])
                  u[col] = encryptVal
                end
              end
              u.save
            end
          end
        else
          raise StandardError, "No such file or directory"
        end
      end
    end
  end
