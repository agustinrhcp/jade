Gem::Specification.new do |s|
  s.name        = 'jade-sql'
  s.version     = '0.1.0'
  s.summary     = 'Type-safe SQL extension for Jade'
  s.authors     = ['agustin']
  s.files       = Dir['lib/**/*']
  s.require_paths = ['lib']
  s.add_dependency 'jade'
end
