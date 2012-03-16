module TSP
  require 'yaml'

  class TelecomServiceProvider
    DATA = YAML.load_file(File.join(File.dirname(__FILE__), 'data', 'telecom_service_providers.yaml')) || {}

    def self.all
      DATA
    end
  end
end
