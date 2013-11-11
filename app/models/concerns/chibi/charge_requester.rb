module Chibi
  module ChargeRequester
    extend ActiveSupport::Concern

    included do
      has_one :charge_request, :as => :requester
    end

    def charge_request_updated!
    end
  end
end
