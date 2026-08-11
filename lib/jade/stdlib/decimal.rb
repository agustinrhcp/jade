require 'jade/stdlib/compiled'

module Jade
  module Stdlib
    module Decimal
      extend self
      extend Compiled

      def uri
        'decimal.jd'
      end

      def imports
        [Basics, Maybe, String, Tuple, Decode, Encode]
      end

      def default_imports
        []
      end

      def code
        <<~JADE
          module Decimal exposing (
            Decimal,
            coefficient,
            div,
            exponent,
            of,
            parse,
            round,
            scaled,
            to_float,
            to_i,
          )

          import Maybe
          import Decode exposing (Decodable, Decoder)
          import Encode exposing (Encodable)


          # An exact base-10 decimal: value = coefficient * 10 ^ exponent.
          # Lossless for money and rates — no Float rounding. Opaque: build one
          # with `of`, `scaled`, or `parse`.
          type Decimal = Decimal(Int, Int)


          # value = coefficient * 10 ^ exponent. of(825, -6) = 0.000825.
          def of(coeff: Int, exp: Int) -> Decimal
            Decimal(coeff, exp)
          end


          # `scale` digits after the decimal point. scaled(825, 4) = 0.0825.
          def scaled(unscaled: Int, scale: Int) -> Decimal
            of(unscaled, 0 - scale)
          end


          def coefficient(d: Decimal) -> Int
            Decimal(m, _) = d

            m
          end


          def exponent(d: Decimal) -> Int
            Decimal(_, e) = d

            e
          end


          def pow10(n: Int) -> Int
            n <= 0 ? 1 : 10 * pow10(n - 1)
          end


          def abs(x: Int) -> Int
            x < 0 ? 0 - x : x
          end


          # Integer division, rounding ties half away from zero (Java HALF_UP /
          # Ruby BigDecimal default: 2.5 -> 3, -2.5 -> -3). A zero `den` raises
          # through Int `/`.
          def round_div(num: Int, den: Int) -> Int
            negative = not ((num < 0) == (den < 0))
            n = abs(num)
            d = abs(den)
            q = n / d
            r = n - q * d
            rounded = (2 * r) >= d ? q + 1 : q

            negative ? 0 - rounded : rounded
          end


          def trunc_div(num: Int, den: Int) -> Int
            q = abs(num) / abs(den)

            num < 0 ? 0 - q : q
          end


          # `+` `-` `*` are exact. `+`/`-` line the operands up on the smaller
          # exponent first; `*` adds exponents.
          def add(a: Decimal, b: Decimal) -> Decimal
            Decimal(ma, ea) = a
            Decimal(mb, eb) = b
            e = ea < eb ? ea : eb

            Decimal((ma * pow10(ea - e)) + (mb * pow10(eb - e)), e)
          end


          def sub(a: Decimal, b: Decimal) -> Decimal
            Decimal(ma, ea) = a
            Decimal(mb, eb) = b
            e = ea < eb ? ea : eb

            Decimal((ma * pow10(ea - e)) - (mb * pow10(eb - e)), e)
          end


          def mul(a: Decimal, b: Decimal) -> Decimal
            Decimal(ma, ea) = a
            Decimal(mb, eb) = b

            Decimal(ma * mb, ea + eb)
          end


          # a / b rounded half-up to `scale` decimal places, like Java's
          # BigDecimal.divide(divisor, scale, HALF_UP). Division by zero raises.
          def div(a: Decimal, b: Decimal, scale: Int) -> Decimal
            Decimal(ma, ea) = a
            Decimal(mb, eb) = b
            k = (ea - eb) + scale
            num = k >= 0 ? ma * pow10(k) : ma
            den = k >= 0 ? mb : mb * pow10(0 - k)

            Decimal(round_div(num, den), 0 - scale)
          end


          # The Numeric `/`: like Ruby's BigDecimal `/`, it can't be exact for a
          # repeating quotient (1/3), so it rounds half-up to a generous scale.
          def divide(a: Decimal, b: Decimal) -> Decimal
            div(a, b, 32)
          end


          implements Numeric(Decimal) with
            (+): add,
            (-): sub,
            (*): mul,
            (/): divide
          end


          # Round to `scale` decimal places, half-up. Values with fewer places
          # than `scale` are left untouched.
          def round(d: Decimal, scale: Int) -> Decimal
            Decimal(m, e) = d
            shift = e + scale

            shift >= 0 ? d : Decimal(round_div(m, pow10(0 - shift)), 0 - scale)
          end


          # Truncates toward zero (drops the fractional part).
          def to_i(d: Decimal) -> Int
            Decimal(m, e) = d

            e >= 0 ? m * pow10(e) : trunc_div(m, pow10(0 - e))
          end


          def to_float(d: Decimal) -> Float
            Decimal(m, e) = d

            e >= 0
              ? Basics.to_float(m * pow10(e))
              : Basics.to_float(m) / Basics.to_float(pow10(0 - e))
          end


          # Parse a decimal string: "0.0825", "-12.5", "42". Returns Nothing on
          # anything that isn't a plain base-10 numeral.
          def parse(s: String) -> Maybe(Decimal)
            case String.split(s, ".")
            in [whole] then
              String.to_int(whole) |> Maybe.map((m) -> { of(m, 0) })

            in [whole, frac] then
              String.to_int(whole ++ frac)
                |> Maybe.map((m) -> { of(m, 0 - String.length(frac)) })

            else Nothing
            end
          end


          def to_wire(d: Decimal) -> String
            Decimal(m, e) = d

            String.from_int(m) ++ "e" ++ String.from_int(e)
          end


          # Decodable(Decimal) is registered by Decode itself, which reads
          # this same wire form in Ruby — a numeric column decodes about
          # three times faster than the Jade version of the parse did.


          implements Encodable(Decimal) with
            encoder: (d) -> { Encode.string(to_wire(d)) }
          end
        JADE
      end
    end
  end
end
