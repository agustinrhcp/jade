# Compiles web/examples/*.jd and injects both columns of the diptych into
# index.html. Run it after touching an example, or after the compiler changes:
#
#   ruby web/build.rb
#
# Exits non-zero if anything fails to compile, so CI can assert the Ruby column
# is not stale:
#
#   ruby web/build.rb && git diff --exit-code web/index.html

require 'fileutils'

WEB = __dir__
JADE_LIB = ENV.fetch('JADE_LIB', File.expand_path('../lib', WEB))

$LOAD_PATH.unshift(JADE_LIB)
require 'jade'

EXAMPLES = %w[shapes pipelines records].freeze

PREAMBLE = /\A(?:\$LOAD_PATH.*|require .*|require_relative .*|\s*)*\n(?=module )/

def compile(name)
  reg = Jade::ModuleLoader.load("#{WEB}/examples", "#{name}.jd", tolerant: true)
  mod = reg.modules.values.reject { Jade::Stdlib.is_stdlib?(it) }.last

  errors = mod.diagnostics.items.select { it.severity == :error }
  unless errors.empty?
    warn "#{name}.jd failed to compile:"
    errors.each { warn "  #{it.message}" }
    exit 1
  end

  mod.diagnostics.items.each { warn "#{name}.jd: #{it.severity} #{it.message}" }
  mod.generated.sub(PREAMBLE, '')
end

def escape(text)
  text
    .gsub('&', '&amp;')
    .gsub('<', '&lt;')
    .gsub('>', '&gt;')
end

def inject(html, tag, attr, slot, body)
  pattern = /(<#{tag}[^>]*#{attr}="#{Regexp.escape(slot)}"[^>]*>).*?(<\/#{tag}>)/m

  unless html.match?(pattern)
    warn "no #{tag} slot #{attr}=\"#{slot}\" in index.html"
    exit 1
  end

  html.sub(pattern) { "#{$1}#{escape(body.strip)}#{$2}" }
end

index = File.read("#{WEB}/index.html")

EXAMPLES.each do |name|
  source = File.read("#{WEB}/examples/#{name}.jd")

  index = inject(index, 'textarea', 'data-src', name, source)
  index = inject(index, 'pre', 'data-gen', "#{name}.rb", compile(name))
end

File.write("#{WEB}/index.html", index)
puts "compiled #{EXAMPLES.size} examples with jade at #{JADE_LIB}"
