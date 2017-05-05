source 'https://rubygems.org'

ruby(File.read(".ruby-version").strip) if ENV["GEMFILE_LOAD_RUBY_VERSION"].to_i == 1 && File.exist?(".ruby-version")

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '4.2.8'
gem 'pg'
gem 'phony_rails'
gem 'faker'
gem 'puma'
gem 'redis'
gem 'torasup'
gem 'aasm'
gem 'twilio-ruby'
gem 'sidekiq'
gem 'sinatra', :require => false

gem 'rails_12factor', :group => :production

group :produciton do
  gem 'airbrake'
end

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
  gem 'dotenv'
end
