source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

#ruby '2.7.5'

gem 'rails',                      '~> 7.1.0'
gem 'image_processing',           '~> 1.9'
gem 'mini_magick',                '~> 4.9.5'
gem 'active_storage_validations', '~> 0.8.9'
gem 'bcrypt',                     '~> 3.1.13'
gem 'faker',                      '~> 3.0'
gem 'will_paginate',              '~> 3.3.0'
gem 'bootstrap-will_paginate',    '~> 1.0.0'
gem 'bootstrap-sass',             '~> 3.4.1'
gem 'puma',                       '~> 6'
gem 'sass-rails',                 '~> 6.0.0'
gem 'webpacker',                  '~> 5.4.0'
gem 'turbolinks',                 '~> 5.2.1'
gem 'jbuilder',                   '~> 2.10.0'
gem 'bootsnap',                   '~> 1.7.2', require: false

group :development, :test do
  gem 'sqlite3', '~> 1.4'
  gem 'byebug',  '11.1.3', platforms: [:mri, :mingw, :x64_mingw]
end

group :development do
  gem 'web-console',        '4.1.0'
  gem 'listen',             '~> 3'
  gem 'spring',             '2.1.1'
end

group :test do
  gem 'matrix'  # required by capybara 3.35.3, removed from Ruby stdlib in 3.1
  gem 'rexml'   # required by selenium-webdriver 3.142.7, removed from Ruby stdlib in 3.1
  gem 'capybara',                 '3.35.3'
  gem 'selenium-webdriver',       '3.142.7'
  gem 'webdrivers',               '4.6.0'
  gem 'rails-controller-testing', '1.0.5'
  gem 'minitest',                 '5.11.3'
  gem 'minitest-reporters',       '1.3.8'
  gem 'guard',                    '2.16.2'
  gem 'guard-minitest',           '2.4.6'
end

group :production do
  #gem 'sqlite3', '~> 1.4'
  #gem 'pg',         '~> 1.0'
  gem 'aws-sdk-s3', '~> 1.87', require: false
  
  gem 'rails_semantic_logger'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# Uncomment the following line if you're running Rails
# on a native Windows system:
# gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Instrument the application with tracing functionality.
# Even though this is a debugger demo, 1) we may want to correlate DI and
# traces in the UI and 2) virtually all DI customers have tracing enabled
# therefore demonstrating DI in a tracing-enabled environment is probably
# what is actually desired most of the time.
case tracer_version = ENV['DD_TRACER']
when nil, ''
  puts "Using datadog most recent release"
  gem 'datadog', require: 'datadog/auto_instrument'
when /\A\//
  puts "Using datadog from local path: #{tracer_version}"
  gem 'datadog', path: tracer_version, require: 'datadog/auto_instrument'
when /\A(git+|http)/
  url, ref = tracer_version.split('@')
  url.sub!(/\Agit\+/, '')
  ref ||= 'master'
  if ref.empty?
    ref = 'master'
  end
  puts "Using datadog from git: #{url} at #{ref}"
  gem 'datadog', git: url, ref: ref, require: 'datadog/auto_instrument'
when String
  puts "Using datadog #{tracer_version}"
  gem 'datadog', tracer_version, require: 'datadog/auto_instrument'
else
  raise "Unknown tracer version specification: #{tracer_version}"
end
