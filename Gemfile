source "https://rubygems.org"

gemspec

ruby '1.9.3', engine: 'jruby', engine_version: '1.7.12'

gem 'grape', github: 'intridea/grape'

# eventually add these as dependencies in gemspec
gem 'rosette-core', '~> 1.0.0', path: '~/workspace/rosette-core'
gem 'activerecord', '~> 4.0.0'
gem 'activerecord-jdbcmysql-adapter', '~> 1.3.0'

gem 'rosette-extractor-rb', path: '~/workspace/rosette-extractor-rb'
gem 'rosette-extractor-js', path: '~/workspace/rosette-extractor-js'
gem 'rosette-extractor-coffee', path: '~/workspace/rosette-extractor-coffee'
gem 'commonjs-rhino', path: '~/workspace/commonjs-rhino'
gem 'puma'

group :development, :test do
  gem 'pry', '~> 0.9.0'
  gem 'pry-nav'
  gem 'rake'
  gem 'threaded'
end

group :test do
  gem 'rspec'
  gem 'rr'
end
