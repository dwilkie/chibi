Torasup.configure do |config|
  config.custom_pstn_data_file = "#{Rails.root}/config/custom_operators.yaml"
  config.register_operators("kh", "smart", "cootel")
end
