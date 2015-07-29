source "https://rubygems.org"

gemspec

ruby '2.0.0', engine: 'jruby', engine_version: '1.7.15'

gem 'rosette-core', '~> 1.0.0', path: '~/workspace/rosette-core'

group :development, :test do
  gem 'jbundler'
  gem 'pry', '~> 0.9.0'
  gem 'pry-nav'
  gem 'rake'
  gem 'puma'
end

group :test do
  gem 'rack-test'
  gem 'rosette-datastore-memory', path: '~/workspace/rosette-datastore-memory'
  gem 'rspec'
  gem 'rspec-mocks'
  gem 'tmp-repo'
end
