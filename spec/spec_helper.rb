require 'spork'

Spork.prefork do
  # This file is copied to spec/ when you run 'rails generate rspec:install'
  ENV["RAILS_ENV"] ||= 'test'

  # Prevent main application to eager_load in the prefork block (do not load files in autoload_paths)
  require 'rails/application'
  Spork.trap_method(Rails::Application, :eager_load!)

  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
end

Spork.each_run do
  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.

  # Reloading each model causes callbacks to be run twice!
  #Dir[Rails.root.join("app/**/*.rb")].each { |f| load f }
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

  RSpec.configure do |config|
    # == Mock Framework
    #
    # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
    #
    # config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr
    config.mock_with :rspec

    # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
    config.fixture_path = "#{::Rails.root}/spec/fixtures"

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = false

    config.treat_symbols_as_metadata_keys_with_true_values = true
    #config.filter_run :focus => true

    # use database cleaner if not using transactional fixtures

    config.before(:suite) do
      DatabaseCleaner.strategy = :truncation
    end

    config.before(:each) do
      DatabaseCleaner.start
    end

    config.after(:each) do
      DatabaseCleaner.clean
    end
  end
end
