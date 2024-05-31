task :replace_encryption_key => [:environment] do
		new_key = ''
		STDOUT.puts "Enter new encryption key with 32 character"
		new_key = STDIN.gets.chomp
		data = YAML::load_file(Rails.root+'plugins/redmine_wktime/config/config.yml')
		old_key = data['encryption_key']
		data['encryption_key'] = new_key
		File.open(Rails.root+'plugins/redmine_wktime/config/config.yml', 'w') { |f| YAML.dump(data, f) }
		data = {WkUser: ['account_number', 'tax_id', 'ss_id']}
		data.each do |key, value|
			model = key.to_s.constantize
			model.all.each do |u|
				value.each do |column|
					if u[column].present?
						crypt = ActiveSupport::MessageEncryptor.new(old_key)
						decryptVal = crypt.decrypt_and_verify(u[column])
						crypt = ActiveSupport::MessageEncryptor.new(new_key)
						encryptVal = crypt.encrypt_and_sign(decryptVal)
						u[column] = encryptVal
						u.save
					end
				end
			end
		end
end