source 'https://rubygems.org'
ruby "2.0.0"

gem 'rails', '3.2.13'
gem 'haml'
gem 'pg'
gem 'kaminari'
gem "lazy_high_charts"
gem "geocoder"
gem "phony"
gem "countries", :require => 'iso3166', :git => "git://github.com/dwilkie/countries.git", :branch => "abbreviations_for_subdivisions_in_thailand"
gem "faker"
gem "hirefire-resource"
gem "resque"
gem "thin"
gem "redis"
gem "torasup"
gem "nuntium_api"
gem "state_machine"
gem "twilio-ruby"
gem "honeybadger"

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'jquery-ui-rails'
  gem 'sass-rails', "  ~> 3.2.3"
  gem 'coffee-rails', "~> 3.2.1"
  gem 'uglifier'
end

gem 'jquery-rails'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

group :test, :development do
  gem 'rspec-rails'
end

group :development do
  gem "parallel_tests"
  gem "foreman"
end

group :test do
  gem 'factory_girl'
  gem 'spork', :git => 'git://github.com/sporkrb/spork.git'
  gem 'fakeweb'
  gem 'vcr', :git => 'git://github.com/myronmarston/vcr.git'
  gem 'guard-rspec'
  gem 'guard-spork'
  gem 'rb-inotify'
  gem 'database_cleaner'
  gem 'timecop'
  gem 'resque_spec'
  gem 'capybara'
  gem 'launchy'
end
