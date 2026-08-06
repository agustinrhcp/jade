require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'jade/api'

module Jade
  describe Api do
    subject(:api) { Api.load(nil) }

    def signature(qualified_name)
      api.lookup(qualified_name)&.fetch(:signature)
    end

    describe '#modules' do
      it 'lists every stdlib module, including the nested ones' do
        expect(api.modules.map { it[:name] })
          .to include('Maybe', 'List', 'Decode', 'Decode.Params')
      end

      it 'marks where a module came from' do
        expect(api.modules.map { it[:origin] }.uniq).to eql ['stdlib']
      end
    end

    describe '#describe' do
      it 'is nil for a module that does not exist' do
        expect(api.describe('Mabye')).to be_nil
      end

      it 'covers a module written as a Ruby DSL, which has no `def` to grep' do
        expect(api.describe('List')[:symbols].map { it[:name] })
          .to include('map', 'fold', 'filter_map', 'partition')
      end

      it 'reports what a type implements' do
        expect(api.describe('Maybe')[:symbols].first)
          .to include(
            kind: 'type',
            signature: 'type Maybe(a)',
            variants: %w[Just Nothing],
            implements: ['Basics.Chainable', 'Basics.Mappable'],
          )
      end

      it 'reports what implements an interface' do
        api
          .lookup('Decode.Decodable')
          .then { expect(it[:implemented_by]).to include('Basics.Int', 'Decimal.Decimal') }
      end

      it 'hides constructors the stdlib keeps private' do
        expect(api.describe('Tuple')[:symbols].map { it[:name] })
          .not_to include('Tuple2')
      end
    end

    describe '#lookup' do
      it 'qualifies a value so the signature reads the way you call it' do
        expect(signature('List.map')).to eql 'List.map : (List(a), (a) -> b) -> List(b)'
      end

      it 'spells out a struct, since the fields are the thing you need' do
        expect(signature('Calendar.Date'))
          .to eql 'struct Date = { year : Int, month : Month, day : Int }'
      end

      it 'carries interface constraints' do
        expect(signature('List.sort')).to eql 'List.sort : Comparable a => (List(a)) -> List(a)'
      end

      it 'renders a constructor as the function it is' do
        expect(signature('Maybe.Just')).to eql 'Maybe.Just : (a) -> Maybe(a)'
      end

      # `Dict.empty()` is a compile error — it's a value. Rendering it as
      # `() -> Dict(k, v)` would invite the call that doesn't work.
      it 'renders a zero-argument entry as the value it is' do
        expect(signature('Dict.empty')).to eql 'Dict.empty : Dict(k, v)'
      end

      it 'is nil for a name no module exposes' do
        expect(api.lookup('List.fold_left')).to be_nil
      end

      # The module env's scheme for a stdlib function backing an interface
      # collapses its type variables — `Result.map` reads there as
      # `(Result(a, e), (a) -> a) -> Result(a, e)`, which says the function
      # cannot change the element type. It can. Read the declaration.
      it 'reports the declared variables, not the env scheme collapsed ones' do
        expect(signature('Maybe.map'))
          .to eql 'Maybe.map : (Maybe(a), (a) -> b) -> Maybe(b)'
        expect(signature('Result.map'))
          .to eql 'Result.map : (Result(a, e), (a) -> b) -> Result(b, e)'
      end
    end

    describe '#search' do
      it 'finds a name across modules, with the differences in view' do
        api
          .search('fold')
          .map { it[:signature] }
          .then do |found|
            expect(found).to include('List.fold : (List(a), b, (b, a) -> b) -> b')
            expect(found).to include('Dict.fold : (Dict(k, v), b, (k, v, b) -> b) -> b')
          end
      end

      it 'matches on the qualified name too' do
        expect(api.search('Encode.').map { it[:name] }).to include('object')
      end

      it 'is empty for a name nothing exposes' do
        expect(api.search('fold_left')).to be_empty
      end
    end

    describe 'inside a project' do
      subject(:api) { Api.load(Project.find(root)) }

      let(:root) { Dir.mktmpdir('jade-api-spec') }

      before do
        FileUtils.mkdir_p(File.join(root, 'lib/ledger'))
        File.write(File.join(root, 'jade.json'), JSON.generate(source_roots: ['lib']))
        File.write(File.join(root, 'lib/ledger/entry.jd'), <<~JADE)
          module Ledger.Entry exposing (Entry, Kind(..), post)

          struct Entry = {
            id: Int,
            cents: Int
          }


          type Kind
            = Debit
            | Credit


          def post(e: Entry, k: Kind) -> Result(Entry, String)
            case k
            in Debit then Ok(e)
            in Credit then Err("nope")
            end
          end
        JADE
      end

      after { FileUtils.rm_rf(root) }

      it 'reports the project\'s own modules alongside the stdlib' do
        expect(api.modules.map { it[:name] }).to include('Ledger.Entry', 'Maybe')
      end

      it 'says which modules are yours' do
        expect(api.describe('Ledger.Entry')[:origin]).to eql 'project'
        expect(api.describe('Maybe')[:origin]).to eql 'stdlib'
      end

      it 'types a project function the way you would call it' do
        expect(signature('Ledger.Entry.post'))
          .to eql 'Ledger.Entry.post : (Entry, Kind) -> Result(Entry, String)'
      end

      it 'spells out a project struct' do
        expect(signature('Ledger.Entry.Entry'))
          .to eql 'struct Entry = { id : Int, cents : Int }'
      end

      it 'searches the project surface, not just the stdlib' do
        expect(api.search('post').map { it[:qualified_name] })
          .to include('Ledger.Entry.post')
      end

      it 'names a module it could not load rather than dropping it silently' do
        File.write(File.join(root, 'lib/broken.jd'), 'module Broken exposing (')

        expect(api.skipped).to include('broken.jd')
      end
    end
  end
end
