require 'spec_helper'

require 'jade'

describe 'requiring jade from a ruby file' do
  compiler = Jade::Compiler.new do |c|
    c.source_root = 'spec/interop'
    c.project_root = File.expand_path("../..", __dir__)
  end

  compiler.require('required')

  it 'works' do
    expect(Required.is_empty('')).to be true
    expect(Required.is_empty('hello')).to be false
  end

  it 'is idempotent across compiler instances' do
    config_block = ->(c) {
      c.source_root  = 'spec/interop'
      c.project_root = File.expand_path("../..", __dir__)
    }

    load_calls = 0
    Jade::ModuleLoader.singleton_class.prepend(Module.new {
      define_method(:load) { |*a, **kw| load_calls += 1; super(*a, **kw) }
    })

    Jade::Compiler.new(&config_block).require('required')
    Jade::Compiler.new(&config_block).require('required')

    expect(load_calls).to eq 0
  end
end
