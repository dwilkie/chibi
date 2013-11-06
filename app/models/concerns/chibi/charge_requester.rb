module Chibi
  module ChargeRequester
    extend ActiveSupport::Concern

    included do
      has_one :charge_request, :as => :requester
    end
  end
end
