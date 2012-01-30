source 'http://rubygems.org'

gem 'rails', '3.2.1'
gem 'haml'
gem 'conversational', '~> 0.4.2'
gem 'pg'
gem 'kaminari'
gem "geocoder", :git => "git://github.com/alexreisner/geocoder.git"
gem "phony"
gem "countries", :git => "git://github.com/hexorx/countries.git", :require => 'iso3166'
gem "faker"

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
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
  gem 'ruby-debug19', :require => 'ruby-debug'
end

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
  gem 'factory_girl'
  gem 'spork', :git => 'git://github.com/sporkrb/spork.git'
  gem 'fakeweb'
  gem 'vcr', :git => 'git://github.com/myronmarston/vcr.git'
  gem 'guard-rspec'
  gem 'guard-spork'
  gem 'database_cleaner'
  gem 'timecop'
end
