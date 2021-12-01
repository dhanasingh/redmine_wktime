class UpdateWkUser < ActiveRecord::Migration[5.2]
  def change
    reversible do |dir|
      if File.exist?(Rails.root+'plugins/redmine_wktime/config/config.yml')
        columnName =  ['account_number', 'tax_id', 'ss_id', 'retirement_account']
        data = YAML::load_file(Rails.root+'plugins/redmine_wktime/config/config.yml')
        key = data['encryption_key']
        crypt = ActiveSupport::MessageEncryptor.new(key)
        dir.up do
          WkUser.all.each do |u|
            columnName.each do |column|
              if u[column].present?
                encryptVal = crypt.encrypt_and_sign(u[column])
                u[column] = encryptVal
              end
            end
            u.save
          end
        end
        dir.down do
          WkUser.all.each do |u|
            columnName.each do |column|
              if u[column].present?
                decryptVal = crypt.decrypt_and_verify(u[column])
                u[column] = decryptVal
              end
            end
            u.save
          end
        end
      else
        raise StandardError, "No file in config"
      end
    end
  end
end
