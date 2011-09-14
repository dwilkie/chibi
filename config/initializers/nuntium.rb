class Nuntium
  CONFIG = %w{url account application password incoming_user incoming_password}

  class << self
    CONFIG.each do |config|
      define_method(config) do
        ENV["NUNTIUM_#{config.upcase}"]
      end
    end
  end

  def self.new_from_config
    new url, account, application, password
  end

  def self.send_ao(messages)
    nuntium = new_from_config
    nuntium.send_ao messages
  end
end

