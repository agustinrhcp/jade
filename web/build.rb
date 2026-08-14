# Injects compiled examples into the pages. CI runs it and fails on a diff.

require 'fileutils'
require 'tmpdir'

WEB = __dir__
JADE_LIB = ENV.fetch('JADE_LIB', File.expand_path('../lib', WEB))

$LOAD_PATH.unshift(JADE_LIB)
require 'jade'

PAGES = %w[index.html tour.html].freeze

# A module's file name has to imply its declared name, so each directory is
# its own source root.
ROOTS = {
  '' => 'examples',
  'tour/' => 'examples/tour',
  'project/' => 'examples/project/src',
}.freeze

PREAMBLE = /\A(?:\$LOAD_PATH.*|require .*|require_relative .*|\s*)*\n(?=module )/

def examples
  ROOTS.flat_map do |prefix, dir|
    Dir.glob("#{WEB}/#{dir}/*.jd")
      .sort
      .map { ["#{prefix}#{File.basename(it, '.jd')}", dir, File.basename(it)] }
  end
end

def compile(dir, file)
  Jade::ModuleLoader
    .load("#{WEB}/#{dir}", file, tolerant: true)
    .modules
    .values
    .reject { Jade::Stdlib.is_stdlib?(it) }
    .last
    .tap { report!(file, it.diagnostics.items) }
end

def report!(file, items)
  items.each { warn "#{file}: #{it.severity} #{it.message}" }
  return if items.none? { it.severity == :error }

  warn "#{file} failed to compile"
  exit 1
end

def escape(text)
  text
    .gsub('&', '&amp;')
    .gsub('<', '&lt;')
    .gsub('>', '&gt;')
end

def slot(html, tag, attr, name, body)
  pattern = /(<#{tag}[^>]*#{attr}="#{Regexp.escape(name)}"[^>]*>).*?(<\/#{tag}>)/m

  html.gsub(pattern) { "#{$1}#{escape(body.strip)}#{$2}" }
end

def project_transcript
  Dir.mktmpdir do |build|
    Jade::ModuleLoader
      .load("#{WEB}/examples/project/src", 'cart.jd', tolerant: true)
      .then { Jade::ModuleLoader.emit(it, path: build) }

    $LOAD_PATH.unshift(build)
    require File.join(build, 'cart')

    lines = [
      { 'name' => 'Coffee', 'cents' => 450, 'qty' => 2 },
      { 'name' => 'Book', 'cents' => 1200, 'qty' => 1 },
    ]

    [
      'irb> Cart.subtotal(lines)',
      "=> #{Cart.subtotal(lines).inspect}",
      '',
      'irb> Cart.receipt(lines)',
      "=> #{Cart.receipt(lines).inspect}",
      '',
      'irb> Cart.subtotal([{ "qty" => "two", ... }])',
      "=> #{decode_failure}",
    ].join("\n")
  end
end

def decode_failure
  Cart.subtotal([{ 'name' => 'Tea', 'cents' => 300, 'qty' => 'two' }])
  raise 'expected the boundary to reject a String qty'
rescue Jade::Interop::DecodeError => e
  "#{e.class}:\n   #{e.message.lines.first.strip}"
end

compiled = examples.to_h { |name, dir, file| [name, compile(dir, file)] }
transcript = project_transcript

PAGES.each do |page|
  path = "#{WEB}/#{page}"
  next unless File.exist?(path)

  html = File.read(path)

  compiled.each do |name, mod|
    source = File.read("#{WEB}/#{ROOTS.fetch(name[%r{\A\w+/}].to_s)}/#{name.split('/').last}.jd")

    html = slot(html, 'textarea', 'data-src', name, source)
    html = slot(html, 'pre', 'data-src', name, source)
    html = slot(html, 'pre', 'data-gen', "#{name}.rb", mod.generated.sub(PREAMBLE, ''))
  end

  html = slot(html, 'pre', 'data-run', 'project', transcript)

  File.write(path, html)
end

puts "compiled #{compiled.size} examples with jade at #{JADE_LIB}"
