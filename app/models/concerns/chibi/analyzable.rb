module Chibi
  module Analyzable
    extend ActiveSupport::Concern

    module ClassMethods
      # this returns the data in the format required by HighStocks
      def overview_of_created(options = {})
        group_by_timeframe(options).to_a
      end

      def group_by_timeframe(options = {}, &block)
        group_by_column = options[:group_by_column] ||= :created_at
        group_by_column = "#{table_name}.#{group_by_column}"

        timeframe = options[:timeframe] || :day
        timeframe_format = options[:timeframe_format] ||= :highcharts

        scope = where.not(group_by_column => nil)

        scope = scope.where(
          "#{group_by_column} >= ?", options[:least_recent].ago
        ) if options[:least_recent]

        scope = scope.between_dates(
          options.merge(:date_column => group_by_column)
        ).by_operator(options).order(group_by_column)

        include_columns = [options[:include_columns] || []].flatten

        if options[:by_user]
          include_columns << "user_id"
          users = {}
        end

        mapping_keys = include_columns.dup.prepend(group_by_column)

        # Use ruby so that the timezone is respected
        scope.pluck(group_by_column, *include_columns).inject(Hash.new(0)) do |h, e|
          element = [e].flatten
          column_mappings = Hash[mapping_keys.zip(element)]
          timestamp = column_mappings[group_by_column]
          group_by_key = timeframe_format == :highcharts ? timestamp.send("beginning_of_#{timeframe}").to_i * 1000 : timestamp.send(timeframe)
          unless options[:by_user] && users[group_by_key].try(:[], column_mappings["user_id"])
            h[group_by_key] += block_given? ? yield(column_mappings) : 1
            if options[:by_user]
              users[group_by_key] ||= {}
              users[group_by_key][column_mappings["user_id"]] = true
            end
          end
          h
        end
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
