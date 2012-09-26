module Analyzable
  extend ActiveSupport::Concern

  module ClassMethods
    # this returns the data in the format required by HighStocks
    def overview_of_created(least_recent = nil)
      date_sql = "DATE(created_at)"
      order_and_group_by_sql = "EXTRACT(EPOCH FROM #{date_sql}) * 1000"
      scope = scoped
      scope = scope.where("#{date_sql} >= ?", least_recent.ago) if least_recent
      scope.order(order_and_group_by_sql).group(order_and_group_by_sql).count.integerify_keys!.to_a
    end
  end
end
