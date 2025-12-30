require 'spec_helper'

require 'jade'

describe 'requiring jade from a ruby file' do
  compiler = Jade::Compiler.new do |c|
    c.source_root = 'spec/interop'
    c.project_root = File.expand_path("../..", __dir__)
  end

  compiler.require('required')

  it 'works' do
    expect(Required.is_empty.call('')).to be true
    expect(Required.is_empty.call('hello')).to be false
  end
end
