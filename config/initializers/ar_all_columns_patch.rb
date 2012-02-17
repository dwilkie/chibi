# returns fully qualified column names
# see: https://github.com/rails/rails/issues/1515
# see also: http://stackoverflow.com/questions/4599010/heroku-postgresql-group-by-error-in-rails-app
# this can be removed in Postgres 9.1

module ActiveRecord
  class Base
    def self.all_columns
      column_names.collect { |c| "#{table_name}.#{c}" }.join(",")
    end
  end
end
