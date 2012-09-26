module Analyzable
  extend ActiveSupport::Concern

  module ClassMethods
    # this returns the data in the format required by HighStocks
    def overview_of_created(options = {})
      count_args = "DISTINCT(#{table_name}.user_id)" if options[:by_user]
      date_sql = options[:timeframe] ? "DATE_TRUNC('#{options[:timeframe]}', created_at)" : "DATE(created_at)"
      group_by_sql = "EXTRACT(EPOCH FROM #{date_sql}) * 1000"

      scope = scoped

      scope = scope.where(
        "#{table_name}.created_at} >= ?", options[:least_recent].ago
      ) if options[:least_recent]

      # hack to get the table alias name
      table_alias = scope.send(:column_alias_for, group_by_sql)

      scope.order(table_alias).group(group_by_sql).count(count_args).integerify_keys!.to_a
    end
  end
end
