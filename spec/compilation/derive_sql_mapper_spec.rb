require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'deriving SqlMapper' do
    include_context 'with test compiler'

    # Stands in for jade-sql, which jade does not depend on. The deriver
    # assumes exactly these shapes, so this is also where that coupling is
    # written down.
    let(:sql_source) do
      <<~JADE.strip
        module Sql exposing (Assignment(..), SqlMapper, to_assigns)

        import Decode exposing (Value)


        struct Assignment = {
          col: String,
          value_sql: String,
          params: List(Value)
        }


        interface SqlMapper(a) with
          to_assigns : a -> List(Assignment)
        end
      JADE
    end

    let(:fields_source) do
      <<~JADE.strip
        module Fields exposing (Field(..), assigns)

        import Sql exposing (Assignment, SqlMapper, to_assigns)


        type Field
          = Name(String)
          | TargetCents(Maybe(Int))
          | DefaultEnvelopeId(Maybe(Int))


        def assigns(f: Field) -> List(Assignment)
          to_assigns(f)
        end
      JADE
    end

    before do
      test_compiler.require(sql_source)
      test_compiler.require(fields_source)
    end

    it 'names the column after the variant, in snake_case' do
      expect(Fields::Internal.assigns(Fields::Name['rent']))
        .to eql [Sql::Assignment['name', '?', ['rent']]]
    end

    it 'splits a multi-word variant name' do
      expect(Fields::Internal.assigns(Fields::DefaultEnvelopeId[Maybe::Just[7]]))
        .to eql [Sql::Assignment['default_envelope_id', '?', [7]]]
    end

    it 'encodes the payload through Encodable' do
      expect(Fields::Internal.assigns(Fields::TargetCents[Maybe::Just[50]]))
        .to eql [Sql::Assignment['target_cents', '?', [50]]]
    end

    it 'writes null for Nothing rather than skipping the column' do
      expect(Fields::Internal.assigns(Fields::TargetCents[Maybe::Nothing[]]))
        .to eql [Sql::Assignment['target_cents', '?', [nil]]]
    end

    context 'a variant carrying two values' do
      let(:two_source) do
        <<~JADE.strip
          module Two exposing (Field(..), assigns)

          import Sql exposing (Assignment, SqlMapper, to_assigns)


          type Field
            = Name(String)
            | Range(Int, Int)


          def assigns(f: Field) -> List(Assignment)
            to_assigns(f)
          end
        JADE
      end

      it 'refuses, since two values name one column' do
        expect { test_compiler.require(two_source) }.to raise_error(/SqlMapper/)
      end
    end

    context 'a struct' do
      let(:row_source) do
        <<~JADE.strip
          module Charge exposing (Charge(..), assigns)

          import Sql exposing (Assignment, SqlMapper, to_assigns)


          struct Charge = {
            id: Int,
            name: String,
            balance: Maybe(Int)
          }


          def assigns(c: Charge) -> List(Assignment)
            to_assigns(c)
          end
        JADE
      end

      before { test_compiler.require(row_source) }

      it 'names one column per field, in declaration order' do
        expect(Charge::Internal.assigns(Charge::Charge[1, 'Ana', Maybe::Just[3]]))
          .to eql [
            Sql::Assignment['id', '?', [1]],
            Sql::Assignment['name', '?', ['Ana']],
            Sql::Assignment['balance', '?', [3]],
          ]
      end

      it 'writes null for Nothing rather than skipping the column' do
        expect(Charge::Internal.assigns(Charge::Charge[1, 'Ana', Maybe::Nothing[]]).last)
          .to eql Sql::Assignment['balance', '?', [nil]]
      end
    end

    context 'a struct field renamed to dodge a keyword' do
      let(:reserved_source) do
        <<~JADE.strip
          module Reserved exposing (Entry(..), assigns)

          import Sql exposing (Assignment, SqlMapper, to_assigns)


          struct Entry = {
            type_: String,
            total_: Int
          }


          def assigns(e: Entry) -> List(Assignment)
            to_assigns(e)
          end
        JADE
      end

      before { test_compiler.require(reserved_source) }

      it 'maps back to the column name only when the field name is a keyword' do
        expect(Reserved::Internal.assigns(Reserved::Entry['debit', 5]))
          .to eql [
            Sql::Assignment['type', '?', ['debit']],
            Sql::Assignment['total_', '?', [5]],
          ]
      end
    end

    context 'a generic struct' do
      let(:wrapped_source) do
        <<~JADE.strip
          module Wrapped exposing (Box(..), assigns)

          import Sql exposing (Assignment, SqlMapper, to_assigns)


          struct Box(a) = { value: a }


          def assigns(b: Box(Int)) -> List(Assignment)
            to_assigns(b)
          end
        JADE
      end

      before { test_compiler.require(wrapped_source) }

      it 'encodes the field at the type it was applied to' do
        expect(Wrapped::Internal.assigns(Wrapped::Box[7]))
          .to eql [Sql::Assignment['value', '?', [7]]]
      end
    end

    context 'a different module that happens to be called Sql' do
      let(:imposter_source) do
        <<~JADE.strip
          module Sql exposing (Assignment(..), SqlMapper, to_assigns)

          struct Assignment = {
            label: String,
            weight: Int
          }


          interface SqlMapper(a) with
            to_assigns : a -> List(Assignment)
          end
        JADE
      end

      let(:user_source) do
        <<~JADE.strip
          module Other exposing (Field(..), assigns)

          import Sql exposing (Assignment, SqlMapper, to_assigns)


          type Field = Name(String)


          def assigns(f: Field) -> List(Assignment)
            to_assigns(f)
          end
        JADE
      end

      it 'refuses rather than building its Assignment with the wrong arity' do
        other = TestCompiler.new
        other.require(imposter_source)

        expect { other.require(user_source) }.to raise_error(/SqlMapper/)
      end
    end

    context 'a union with a nullary variant' do
      let(:mixed_source) do
        <<~JADE.strip
          module Mixed exposing (Field(..), assigns)

          import Sql exposing (Assignment, SqlMapper, to_assigns)


          type Field
            = Name(String)
            | Cleared


          def assigns(f: Field) -> List(Assignment)
            to_assigns(f)
          end
        JADE
      end

      it 'refuses, since a nullary variant names no value to assign' do
        expect { test_compiler.require(mixed_source) }.to raise_error(/SqlMapper/)
      end
    end
  end
end
