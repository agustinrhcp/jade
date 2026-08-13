require 'spec_helper'

require 'jade/symbol'
require 'jade/frontend'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'
require 'jade/capabilities'

module Jade
  describe Capabilities do
    let(:source) { Source.new(uri: 'test', text:) }

    let(:run) do
      Lexer
        .tokenize(source)
        .then { Parsing.parse(it, source:) }
        .and_then do |(ast, _)|
          registry, current_entry = Frontend.entry_with_basics(ast)
          Frontend
            .run_entry(current_entry.with(source:), registry)
            .map { registry.update_module(it) }
        end
    end

    let(:registry) { run => Ok(registry); registry }
    subject(:reach) { Capabilities.analyze(registry) }

    def names_of(name)
      reach.fetch(['M', name]).names
    end

    def path_of(name)
      reach
        .fetch(['M', name])
        .atoms
        .values
        .first
        .map { it.join('.') }
    end

    describe 'a function that calls a port' do
      let(:text) do
        <<~JADE
          module M exposing (fetch)

          uses KeyValue with
            members : String -> Task(List(String), String)
          end


          def fetch(key: String) -> Task(List(String), String)
            members(key)
          end


          def untouched(n: Int) -> Int
            n + 1
          end
        JADE
      end

      it 'reaches the port' do
        expect(names_of('fetch')).to eq ['KeyValue.members']
      end

      it 'reaches it directly, with no intermediate hops' do
        expect(path_of('fetch')).to be_empty
      end

      it 'leaves a function that calls nothing effectful pure' do
        expect(reach.fetch(['M', 'untouched'])).to be_pure
      end

      it 'reports the port as an atom of the registry' do
        expect(Capabilities.atoms(registry).map(&:to_s)).to include 'KeyValue.members'
      end
    end

    describe 'propagation up the call graph' do
      let(:text) do
        <<~JADE
          module M exposing (outer)

          uses KeyValue with
            members : String -> Task(List(String), String)
          end


          def outer(key: String) -> Task(List(String), String)
            middle(key)
          end


          def middle(key: String) -> Task(List(String), String)
            inner(key)
          end


          def inner(key: String) -> Task(List(String), String)
            members(key)
          end
        JADE
      end

      it 'carries the port to every caller' do
        expect(names_of('outer')).to eq ['KeyValue.members']
      end

      it 'records the shortest path to it' do
        expect(path_of('outer')).to eq ['M.middle', 'M.inner']
      end
    end

    # `sees_long_first` exists to make the long path reach `top` before the
    # short one: edge order follows reference-index insertion, not source
    # order, so without it a first-path-wins bug passes this example.
    describe 'two paths to the same port' do
      let(:text) do
        <<~JADE
          module M exposing (top)

          uses KeyValue with
            members : String -> Task(List(String), String)
          end


          def sees_long_first(key: String) -> Task(List(String), String)
            long(key)
          end


          def direct(key: String) -> Task(List(String), String)
            members(key)
          end


          def longer(key: String) -> Task(List(String), String)
            direct(key)
          end


          def long(key: String) -> Task(List(String), String)
            longer(key)
          end


          def top(key: String) -> Task(List(String), String)
            case String.empty?(key)
            in True then long(key)
            in False then direct(key)
            end
          end
        JADE
      end

      it 'counts the port once' do
        expect(names_of('top')).to eq ['KeyValue.members']
      end

      it 'keeps the shorter of the two paths' do
        expect(path_of('top')).to eq ['M.direct']
      end
    end

    describe 'a port-calling function passed as a value' do
      let(:text) do
        <<~JADE
          module M exposing (all)

          uses KeyValue with
            members : String -> Task(List(String), String)
          end


          def all(keys: List(String)) -> List(Task(List(String), String))
            List.map(keys, fetch)
          end


          def fetch(key: String) -> Task(List(String), String)
            members(key)
          end
        JADE
      end

      it 'charges the caller that named it' do
        expect(names_of('all')).to eq ['KeyValue.members']
      end

      it 'does not charge the higher-order function it was passed to' do
        expect(reach[['List', 'map']]).to be_nil
      end
    end

    describe 'a call into another module' do
      let(:text) do
        <<~JADE
          module M exposing (stamped)

          import Clock


          def stamped -> Task(Clock.Instant, Never)
            Clock.now
          end


          def offset(d: Clock.Duration) -> Int
            Clock.in_millis(d)
          end
        JADE
      end

      it 'reaches the port behind the stdlib function' do
        expect(names_of('stamped')).to eq ['Jade::Clock::Runtime.now_raw']
      end

      it 'names the stdlib function as the path to it' do
        expect(path_of('stamped')).to eq ['Clock.now']
      end

      it 'leaves pure stdlib calls pure' do
        expect(reach.fetch(['M', 'offset'])).to be_pure
      end
    end

    describe 'an effectful intrinsic' do
      let(:text) do
        <<~JADE
          module M exposing (noisy)

          import Debug


          def noisy(n: Int) -> Int
            Debug.log("n", n)
          end
        JADE
      end

      it 'is an atom even though it is not a port' do
        expect(names_of('noisy')).to eq ['Debug.log']
      end

      it 'is listed among the registry atoms' do
        expect(Capabilities.atoms(registry).map(&:to_s)).to include 'Debug.log'
      end
    end

    describe 'a module the walker never saw' do
      let(:text) do
        <<~JADE
          module M exposing (go)

          def go(n: Int) -> Int
            n + 1
          end
        JADE
      end

      subject(:reach) do
        registry
          .get('M')
          .with(usage_index: nil)
          .then { Capabilities.analyze(registry.update_module(it)) }
      end

      it 'reports its functions as incomplete rather than pure' do
        expect(reach.fetch(['M', 'go']).complete).to be false
      end

      it 'does not let an incomplete node read as pure' do
        expect(reach.fetch(['M', 'go'])).not_to be_pure
      end
    end

    describe '.for' do
      let(:text) do
        <<~JADE
          module M exposing (fetch)

          uses KeyValue with
            members : String -> Task(List(String), String)
          end


          def fetch(key: String) -> Task(List(String), String)
            members(key)
          end
        JADE
      end

      it 'answers for a declared function' do
        registry
          .get('M')
          .lookup_value('fetch')
          .then { expect(Capabilities.for(registry, it).names).to eq ['KeyValue.members'] }
      end

      it 'answers for the port itself' do
        registry
          .get('M')
          .lookup_value('members')
          .then { expect(Capabilities.for(registry, it).names).to eq ['KeyValue.members'] }
      end
    end
  end
end
