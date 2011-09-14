source 'http://rubygems.org'

gem 'rails', '3.1.0'
gem 'nuntium_api', '0.13'
gem 'haml'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

group :development do
  gem 'sqlite3'
end


# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', "  ~> 3.1.0"
  gem 'coffee-rails', "~> 3.1.0"
  gem 'uglifier'
end

group :production do
  gem 'pg'
end

gem 'jquery-rails'

# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
gem 'ruby-debug19', :require => 'ruby-debug', :group => [:development, :test]

group :test do
  # Pretty printed test output
  gem 'turn', :require => false
end

group :test, :development do
  gem "rspec-rails", "~> 2.6"
end

