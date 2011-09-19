source 'http://rubygems.org'

gem 'rails', '3.1.0'
gem 'nuntium_api', '0.13'
gem 'haml'
gem 'state_machine'
gem 'squeel', :git => "git://github.com/ernie/squeel.git"
gem 'conversational'
gem 'sunspot_rails'
gem 'devise'
gem 'pg'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', "  ~> 3.1.0"
  gem 'coffee-rails', "~> 3.1.0"
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
  gem 'spork', :git => 'git://github.com/timcharper/spork.git'
  gem 'fakeweb'
  gem 'guard-rspec'
  gem 'guard-spork'
end

