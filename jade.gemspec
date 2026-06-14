# frozen_string_literal: true

require_relative 'lib/jade/version'

Gem::Specification.new do |spec|
  spec.name        = 'jade-lang'
  spec.version     = Jade::VERSION
  spec.authors     = ['Agustin Cornu']
  spec.email       = ['agustincornu@fastmail.com']

  spec.summary     = 'A functional, type-safe language that compiles to ' \
                     'readable Ruby.'
  spec.description = <<~DESC
    Jade is a statically typed functional language, inspired by Elm, that
    compiles to readable Ruby. It brings Hindley-Milner type inference, union
    types, records, exhaustive pattern matching, and typed boundaries to the
    Ruby ecosystem, while staying interoperable with existing Ruby code.
  DESC

  spec.homepage = 'https://github.com/agustinrhcp/jade'
  spec.license  = 'MIT'

  spec.required_ruby_version = '>= 3.4'

  spec.metadata = {
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/master/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'rubygems_mfa_required' => 'true',
  }

  spec.files = Dir[
    'lib/**/*',
    'exe/*',
    'LICENSE',
    'README.md',
    'CHANGELOG.md',
  ]
  spec.bindir      = 'exe'
  spec.executables = ['jade']
  spec.require_paths = ['lib']

  spec.add_dependency 'base64', '~> 0.2'
end
