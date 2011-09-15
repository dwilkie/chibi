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

  def self.address(addr, with_protocol = false)
    address_without_protocol = addr =~ %r(^(.*?)://(.*?)$) ? $2 : addr
    with_protocol ? "sms://#{address_without_protocol}" : address_without_protocol
  end

  def self.send_mt(message)
    nuntium = new_from_config
    message.merge! "to" => self.address(message["to"], true)
    nuntium.send_ao message
  end
end

