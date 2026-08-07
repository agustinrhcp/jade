require 'date'
require 'jade/tasks'

# Opt-in runtime: requires ActiveRecord. The Jade-side Sql.Run module
# declares ports against this. Loaded only when the user explicitly does
# `require 'jade-sql/runtime'`.
module JadeSql
  module Runtime
    extend Jade::Port

    task :port_execute_count do |t, pair|
      sql, params = pair._1, pair._2
      conn = ::ActiveRecord::Base.connection
      t.ok(conn.exec_update(adapt_sql(sql, conn), "Jade", typed_params(params, conn)))
    rescue ::ActiveRecord::StatementInvalid => e
      t.err(JadeSql::SqlErrors.db_error(e.message))
    end

    task :port_execute_one do |t, pair|
      sql, params = pair._1, pair._2
      conn = ::ActiveRecord::Base.connection
      rows = conn.exec_query(adapt_sql(sql, conn), "Jade", typed_params(params, conn)).to_a
      case rows.length
      when 0 then t.err(JadeSql::SqlErrors.not_found)
      when 1 then t.ok(coerce_row(rows.first))
      else        t.err(JadeSql::SqlErrors.not_unique)
      end
    rescue ::ActiveRecord::StatementInvalid => e
      t.err(JadeSql::SqlErrors.db_error(e.message))
    end

    task :port_execute_many do |t, pair|
      sql, params = pair._1, pair._2
      conn = ::ActiveRecord::Base.connection
      rows = conn.exec_query(adapt_sql(sql, conn), "Jade", typed_params(params, conn)).to_a
      t.ok(rows.map { |row| coerce_row(row) })
    rescue ::ActiveRecord::StatementInvalid => e
      t.err(JadeSql::SqlErrors.db_error(e.message))
    end

    # AR's PG adapter returns ::Date / ::Time for date/timestamp columns;
    # Calendar.Date / Clock.Instant decoders expect ISO strings. Coerce
    # at the boundary so callers don't sprinkle text_cast in every SELECT.
    #
    # text[] / int[] / etc. arrive as Postgres array literals (`{a,b,c}`)
    # when AR's exec_query path doesn't run the OID typecast. Parse them
    # back to Ruby Arrays so `Decode.list(...)` works the same as for any
    # other List(a) column.
    def self.coerce_row(row)
      row.transform_values { |v| coerce_value(v) }
    end

    def self.coerce_value(v)
      case v
      when ::Date             then v.iso8601
      when ::Time, ::DateTime then v.iso8601
      when ::String
        pg_array_literal?(v) ? parse_pg_array(v) : v
      else v
      end
    end

    # PG arrays render as `{}`, `{a,b,c}`, `{"a,b","c"}`, with NULL as
    # bare `NULL`. Quoted elements escape `"` and `\` with backslashes.
    # The JSON-object guard rejects `{"key":...}` shapes — they share the
    # outer braces but should reach Decode.Value as plain strings (or as
    # Hash if AR already typecast the column).
    PG_ARRAY_LITERAL = /\A\{.*\}\z/m
    JSON_OBJECT_HEAD = /\A\{\s*"[^"]*"\s*:/m

    def self.pg_array_literal?(s)
      s.match?(PG_ARRAY_LITERAL) && !s.match?(JSON_OBJECT_HEAD)
    end

    def self.parse_pg_array(s)
      inner = s[1..-2]
      return [] if inner.empty?

      elements = []
      buffer = String.new
      in_quotes = false
      i = 0
      while i < inner.length
        c = inner[i]
        if in_quotes
          if c == '\\' && i + 1 < inner.length
            buffer << inner[i + 1]
            i += 2
            next
          elsif c == '"'
            in_quotes = false
          else
            buffer << c
          end
        else
          if c == '"'
            in_quotes = true
          elsif c == ','
            elements << decode_element(buffer)
            buffer = String.new
          else
            buffer << c
          end
        end
        i += 1
      end
      elements << decode_element(buffer)
      elements
    end

    def self.decode_element(raw)
      raw == "NULL" ? nil : raw
    end

    # Sql renders `?` placeholders uniformly. AR's exec_query/exec_update
    # path on the PG adapter expects `$1, $2, …` — there is no `?`-to-`$n`
    # rewrite at that layer. SQLite and MySQL accept `?` directly, so this
    # is a no-op there. Naive substitution; doesn't dodge `?` inside string
    # literals — fix when someone hits it.
    def self.adapt_sql(sql, conn)
      return sql unless conn.adapter_name =~ /postgres/i

      i = 0
      sql.gsub("?") { i += 1; "$#{i}" }
    end

    # AR's exec_query raw path can't bind a Ruby Array — pg's OID type
    # cast isn't applied to bare values. Wrap arrays in QueryAttribute
    # with a PG OID::Array so the binding picks the right wire format.
    # Element type sniffs the first non-nil entry; falls back to text.
    def self.typed_params(params, conn)
      return params unless conn.adapter_name =~ /postgres/i

      params.map { |p| typed_param(p) }
    end

    def self.typed_param(value)
      case value
      when ::Array
        ::ActiveRecord::Relation::QueryAttribute.new(nil, value, array_type_for(value))
      else
        value
      end
    end

    def self.array_type_for(elements)
      sample = elements.find { |e| !e.nil? }
      element_type =
        case sample
        when ::Integer            then ::ActiveRecord::Type::Integer.new
        when ::Float              then ::ActiveRecord::Type::Float.new
        when true, false          then ::ActiveRecord::Type::Boolean.new
        else                           ::ActiveRecord::Type::String.new
        end

      ::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(element_type)
    end
  end
end
