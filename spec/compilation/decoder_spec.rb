require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Decode.decoder' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module M exposing (
          a_date,
          a_list,
          a_pair,
          a_shade,
          a_tag,
          an_int,
        )

        import Calendar exposing (Date)
        import Decode exposing (Decodable, DecodeError, Decoder)


        type Tag = Tag(String)


        type Pair = Pair(Tag, Date)


        type Shade
          = Dark
          | Light


        def tag_decoder -> Decoder(Tag)
          Decode.map(Decode.string, Tag)
        end


        implements Decodable(Tag) with
          decoder: tag_decoder
        end


        def an_int(json: String) -> Int
          Decode.decode_string(Decode.decoder, json) |> Result.with_default(0)
        end


        def a_date(json: String) -> String
          Decode.decode_string(date_field, json)
            |> Result.map(Calendar.to_iso_string)
            |> Result.with_default("no")
        end


        def date_field -> Decoder(Date)
          Decode.field("on", Decode.decoder)
        end


        def a_list(json: String) -> List(Int)
          Decode.decode_string(Decode.list(Decode.decoder), json)
            |> Result.with_default([])
        end


        def a_tag(json: String) -> String
          Decode.decode_string(Decode.decoder, json)
            |> Result.map(untag)
            |> Result.with_default("no")
        end


        def untag(t: Tag) -> String
          Tag(s) = t
          s
        end


        def a_shade(json: String) -> String
          Decode.decode_string(Decode.decoder, json)
            |> Result.map(shade_name)
            |> Result.with_default("no")
        end


        def shade_name(s: Shade) -> String
          case s
          in Dark then "dark"
          in Light then "light"
          end
        end


        def a_pair(json: String) -> String
          Decode.succeed(Pair(_, _))
            |> Decode.and_map(Decode.field("t", Decode.decoder))
            |> Decode.and_map(Decode.field("on", Decode.decoder))
            |> Decode.decode_string(json)
            |> Result.map(show_pair)
            |> Result.with_default("no")
        end


        def show_pair(p: Pair) -> String
          Pair(t, on) = p
          untag(t) ++ Calendar.to_iso_string(on)
        end
      JADE
    end

    before { test_compiler.require(source) }

    it 'resolves Int from the expected type' do
      expect(M.an_int('7')).to eq 7
    end

    it 'resolves Date inside a field' do
      expect(M.a_date('{"on":"2026-09-10"}')).to eq '2026-09-10'
    end

    it 'resolves Int inside a list' do
      expect(M.a_list('[1,2]')).to eq [1, 2]
    end

    it 'resolves a hand-written instance' do
      expect(M.a_tag('"x"')).to eq 'x'
    end

    it 'resolves a derived instance' do
      expect(M.a_shade('"dark"')).to eq 'dark'
    end

    it 'resolves two different types in one chain' do
      expect(M.a_pair('{"t":"x","on":"2026-09-10"}')).to eq 'x2026-09-10'
    end

    it 'names the type when there is no instance' do
      expect { test_compiler.require(<<~JADE) }
        module N exposing (nope)

        import Decode exposing (Decoder)


        type Opaque = Opaque(Int -> Int)


        def nope -> Decoder(Opaque)
          Decode.decoder
        end
      JADE
        .to raise_error(CompilationError, /Decodable cannot be derived for Opaque/)
    end
  end
end
