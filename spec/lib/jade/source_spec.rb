require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade'

module Jade
  describe Source do
    describe '.load' do
      let(:uri) { 'maybe.jd' }

      subject { described_class.load('src', uri) }

      before { allow(File).to receive(:read) { 'some jade code' } }

      it { is_expected.to be_a(Source) }

      its(:uri) { is_expected.to eql uri }
      its(:text) { is_expected.to eql 'some jade code' }
      its(:to_module_name) { is_expected.to eql 'Maybe' }

      it 'reads the file' do
        expect(File).to receive(:read).with('src/maybe.jd')
        subject
      end
    end

    describe '.load_from_module_name' do
      let(:module_name) { 'Maybe' }

      subject { described_class.load_from_module_name('src', module_name) }

      before { allow(File).to receive(:read) { 'some jade code' } }

      it { is_expected.to be_a(Source) }

      its(:uri) { is_expected.to eql 'maybe.jd' }
      its(:text) { is_expected.to eql 'some jade code' }
      its(:to_module_name) { is_expected.to eql 'Maybe' }

      it 'reads the file' do
        expect(File).to receive(:read).with('src/maybe.jd')
        subject
      end
    end

    describe 'root' do
      let(:project) { Dir.mktmpdir('jade-source-spec') }
      let(:app)     { File.join(project, 'lib') }
      let(:gem_)    { File.join(project, 'jade-sql/lib/jade-sql') }

      before do
        [app, File.join(gem_, 'sql')].each { FileUtils.mkdir_p(it) }
        File.write(File.join(app, 'envelope.jd'), 'module Envelope exposing ()')
        File.write(File.join(gem_, 'sql/uuid.jd'), 'module Sql.Uuid exposing ()')
        Jade.extensions << gem_
      end

      after do
        Jade.extensions.delete(gem_)
        FileUtils.rm_rf(project)
      end

      it 'is the root a module was loaded from' do
        expect(Source.load(app, 'envelope.jd').root).to eql app
      end

      it 'is the extension root for a module an extension ships' do
        expect(Source.load_from_module_name(app, 'Sql.Uuid').root).to eql gem_
      end

      it 'distinguishes an app module from an extension module of the same name' do
        File.write(File.join(app, 'decode.jd'), 'module Decode exposing ()')
        FileUtils.mkdir_p(File.dirname(File.join(gem_, 'decode.jd')))
        File.write(File.join(gem_, 'decode.jd'), 'module Decode exposing ()')

        expect(Source.load_from_module_name(app, 'Decode').root).to eql app
      end

      it 'is nil for a source that never came off disk' do
        expect(Source.new(uri: 'buffer', text: 'x').root).to be_nil
      end
    end
  end
end
