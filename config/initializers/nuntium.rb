class Nuntium
  CONFIG = YAML.load_file(File.expand_path('../../../config/nuntium.yml', __FILE__))[Rails.env]
  def self.new_from_config
    Nuntium.new CONFIG['url'], CONFIG['account'], CONFIG['application'], CONFIG['password']
  end

  def self.send_ao(messages)
    nuntium = Nuntium.new_from_config
    nuntium.send_ao messages
  end
end
