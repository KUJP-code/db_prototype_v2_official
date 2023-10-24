# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.0.6'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 7.0.4'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '< 7'

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem 'importmap-rails'

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'

# Use Redis adapter to run Action Cable in production
# gem "redis", "~> 4.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Sass to process CSS
gem 'sassc-rails'

# Use Bootstrap for CSS
gem 'bootstrap', '~> 5.2.2'

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem 'image_processing', '~> 1.2'

# Use Devise for authentication
gem 'devise'

# Use Pundit for authorisation
gem 'pundit', '~> 2.3'

# Use PaperTrail for backup/reversion of certain models
gem 'paper_trail'

# Localize Devise views so I can read my own app
gem 'devise-i18n'

# Make using AWS easier with their SDK
gem 'aws-sdk-rails', '~> 3'
gem 'aws-sdk-s3', '~> 1'

# Can't use 2.8.0 as it causes issues with EB
gem 'mail', '2.7.1'

# Use Faker to generate test data
gem 'faker'
gem 'faker_japanese'

# Use postgres-copy to import/export .csv data
gem 'postgres-copy'

# Use Kaminari for pagination
gem 'kaminari'

# Create charts from DB
gem 'chartkick'

# Allow easy grouping by time periods
gem 'groupdate'

# Use prawn for PDF invoices
gem 'prawn'

# Use rack-mini-profiler for performance monitoring
gem 'rack-mini-profiler'

# For memory profiling
gem 'memory_profiler'

# For call-stack profiling flamegraphs
gem 'stackprof'

# And oj to serialize it quickly
gem 'oj'

group :development, :test do
  # Capybara for system/feature testing
  gem 'capybara'

  # Selenium for browser based tests
  gem 'selenium-webdriver'

  # Byebug for debugging
  gem 'byebug', platform: :mri

  # RSpec to write test suites
  gem 'rspec-rails', '~> 3.5'

  # Factory bot for test data creation
  gem 'factory_bot_rails'

  # DB cleaner for test data management
  gem 'database_cleaner'

  # Check for N+1/unused eager loading
  gem 'bullet'

  # Use Rubocop to check for dumb mistakes
  gem 'rubocop', '~> 1.40', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Use brakeman for static analysis
  gem 'brakeman'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end
