module Chibi
  module Analyzable
    extend ActiveSupport::Concern

    module ClassMethods
      # this returns the data in the format required by HighStocks
      def overview_of_created(options = {})
        count_args = "DISTINCT(#{table_name}.user_id)" if options[:by_user]
        group_by_timeframe(options).count(count_args).integerify.to_a
      end

      def group_by_timeframe(options = {}, &block)
        group_by_column = options[:group_by_column] ||= :created_at
        group_by_column = "#{table_name}.#{group_by_column}"

        timeframe = options[:timeframe] || :day
        timeframe_format = options[:timeframe_format] ||= :highstocks

        local_timezone = Time.zone.tzinfo.identifier
        local_time_sql = "(TIMESTAMPTZ(#{group_by_column}) AT TIME ZONE '#{local_timezone}')"

        date_sql = timeframe == :day ? "DATE(#{local_time_sql})" : "DATE_TRUNC('#{timeframe}', #{local_time_sql})"
        group_by_sql = timeframe_format == :highstocks ? "EXTRACT(EPOCH FROM #{date_sql}) * 1000" : "EXTRACT(DAY FROM #{date_sql})"

        date_options = options.merge(:date_column => group_by_column)
        scope = between_dates(date_options).recent(date_options).by_operator(options).where.not(group_by_column => nil)

        # hack to get the table alias name
        table_alias = scope.send(:column_alias_for, group_by_sql)

        scope.order(table_alias).group(group_by_sql)
      end

      def recent(options)
        return all unless options[:least_recent]
        where("#{options[:date_column]} >= ?", options[:least_recent].ago)
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
