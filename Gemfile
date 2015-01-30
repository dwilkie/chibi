source 'https://rubygems.org'
ruby "2.2.0"

gem 'rails', '4.2.0'
gem 'haml'
gem 'pg'
gem 'kaminari'
gem "lazy_high_charts"
gem "geocoder"
gem "phony"
gem "countries", :require => 'iso3166', :git => "git://github.com/hexorx/countries.git"
gem "faker"
gem "hirefire-resource"
gem "resque", :git => "git://github.com/dwilkie/resque", :branch => "prevent_resque_failure_1-x-stable"
gem 'resque-web', :require => 'resque_web'
gem "unicorn"
gem "rack-timeout"
gem "redis"
gem "torasup"
gem "nuntium_api", :github => "dwilkie/nuntium-api-ruby"
gem "aasm", :github => "aasm/aasm"
gem "state_machine"
gem "twilio-ruby"
gem "uuid"
gem "multi_xml"
gem "carrierwave"
gem "fog"

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

gem 'sass-rails', '~> 4.0.3'
gem 'coffee-rails', '~> 4.0.0'
gem 'uglifier', '>= 1.3.0'

gem 'jquery-rails'
gem 'turbolinks'

gem 'rails_12factor', :group => :production

group :development do
  gem 'web-console', '~> 2.0'
end

group :test, :development do
  gem 'rspec-rails'
  gem 'parallel_tests'
  gem 'foreman'
  gem 'pry'
end

group :test do
  gem 'factory_girl'
  gem 'mock_redis'
  gem 'fakeweb'
  gem 'vcr'
  gem 'database_cleaner'
  gem 'timecop'
  gem 'resque_spec'
  gem 'capybara'
  gem 'launchy'
end
