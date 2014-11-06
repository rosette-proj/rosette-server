source "https://rubygems.org"

gemspec

ruby '2.0.0', engine: 'jruby', engine_version: '1.7.15'

gem 'grape', '~> 0.9.0'

# eventually add these as dependencies in gemspec
gem 'rosette-core', '~> 1.0.0', path: '~/workspace/rosette-core'
gem 'activerecord', '~> 4.0.0'
gem 'activerecord-jdbcmysql-adapter', '~> 1.3.0'

gem 'rosette-extractor-rb', path: '~/workspace/rosette-extractor-rb'
gem 'rosette-extractor-js', path: '~/workspace/rosette-extractor-js'
gem 'rosette-extractor-coffee', path: '~/workspace/rosette-extractor-coffee'
gem 'rosette-extractor-yaml', path: '~/workspace/rosette-extractor-yaml'
gem 'rosette-serializer-yaml', path: '~/workspace/rosette-serializer-yaml'
gem 'yaml-write-stream', path: '~/workspace/yaml-write-stream'
gem 'commonjs-rhino', path: '~/workspace/commonjs-rhino'
gem 'puma'

group :development, :test do
  gem 'jbundler'
  gem 'pry', '~> 0.9.0'
  gem 'pry-nav'
  gem 'rake'
end

group :test do
  gem 'rack-test'
  gem 'rosette-datastore-memory', path: '~/workspace/rosette-datastore-memory'
  gem 'rspec'
  gem 'rspec-mocks'
  gem 'rr'
  gem 'tmp-repo'
end
