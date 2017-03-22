source 'https://rubygems.org'

ruby(File.read(".ruby-version").strip) if ENV["GEMFILE_LOAD_RUBY_VERSION"].to_i == 1 && File.exist?(".ruby-version")

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '4.2.8'
gem 'haml'
gem 'pg'
gem 'kaminari'
gem 'lazy_high_charts'
gem 'geocoder'
gem 'phony_rails'
gem 'countries'
gem 'faker'
gem 'puma'
gem 'redis'
gem 'torasup'
gem 'aasm'
gem 'twilio-ruby'
gem 'multi_xml'
gem 'carrierwave'
gem 'fog'
gem 'sidekiq'
gem "celluloid", '0.16.0'
gem 'sinatra', :require => false
gem 'airbrake'

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
  gem 'rails_best_practices'
  gem 'spring'
  gem 'spring-commands-rspec'
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
  gem 'webmock'
  gem 'vcr'
  gem 'timecop'
  gem 'capybara'
  gem 'launchy'
  gem 'shoulda-matchers'
  gem 'test_after_commit'
end
