$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'rosette/server/version'

Gem::Specification.new do |s|
  s.name     = "rosette-server"
  s.version  = ::Rosette::Server::VERSION
  s.authors  = ["Cameron Dutro"]
  s.email    = ["camertron@gmail.com"]
  s.homepage = "http://github.com/camertron"

  s.description = s.summary = "Server for the Rosette internationalization platform that manages the translatable content in the source files of a git repository."

  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true

  # s.add_dependency 'grape', '~> 0.8.0'

  s.require_path = 'lib'
  s.files = Dir["{lib,spec}/**/*", "Gemfile", "History.txt", "README.md", "Rakefile", "rosette-server.gemspec"]
end
