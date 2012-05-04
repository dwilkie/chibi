module Analyzable
  extend ActiveSupport::Concern

  module ClassMethods
    def this_month
      scoped.where("created_at >=?", Time.now.beginning_of_month)
    end
  end
end
