module Chibi
  module Analyzable
    extend ActiveSupport::Concern

    module ClassMethods
      # this returns the data in the format required by HighStocks
      def overview_of_created(options = {})
        count_args = "DISTINCT(#{table_name}.user_id)" if options[:by_user]
        format = options[:format] ||= :highcharts
        result = group_by_timeframe(options).count(count_args).integerify!
        format == :report ? result : result.to_a
      end

      def group_by_timeframe(options = {})
        group_by_column = options[:group_by_column] ||= :created_at
        group_by_column = "#{table_name}.#{group_by_column}"

        timeframe = options[:timeframe]

        date_sql = timeframe ? "DATE_TRUNC('#{timeframe}', #{group_by_column})" : "DATE(#{group_by_column})"
        group_by_sql = options[:format] == :report ? "EXTRACT(DAY FROM #{date_sql})" : "EXTRACT(EPOCH FROM #{date_sql}) * 1000"

        scope = where.not(group_by_column => nil)

        scope = scope.where(
          "#{group_by_column} >= ?", options[:least_recent].ago
        ) if options[:least_recent]

        scope = scope.between_dates(options.merge(:date_column => group_by_column))

        scope = scope.by_operator(options)

        # hack to get the table alias name
        table_alias = scope.send(:column_alias_for, group_by_sql)

        scope.order(table_alias).group(group_by_sql)
      end

      def between_dates(options)
        return all unless options[:between]
        options[:date_column] ||= "#{table_name}.created_at"
        where(
          "#{options[:date_column]} >= ?", options[:between].min
        ).where(
          "#{options[:date_column]} <= ?", options[:between].max
        )
      end

      def by_operator(options = {})
        options[:operator] && options[:country_code] ? by_operator_joins.by_country_code(options).by_operator_name(options) : all
      end

      def by_country_code(options)
        where(:locations => {:country_code => options[:country_code]})
      end

      def by_operator_joins
        joins(:user => :location)
      end

      def by_operator_name(options)
        where(by_operator_name_joins_conditions(options))
      end

      def by_operator_name_joins_conditions(options)
        {:users => by_operator_name_conditions(options)}
      end

      def by_operator_name_conditions(options)
        {:operator_name => options[:operator]}
      end
    end
  end
end
