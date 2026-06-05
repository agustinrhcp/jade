require 'spec_helper'

# We want to test the placeholder rewrite without booting AR.
# Stub `ActiveRecord` enough that the runtime file loads.
unless defined?(::ActiveRecord)
  module ActiveRecord
    class Base; end
    class StatementInvalid < StandardError; end
  end
end

unless defined?(::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array)
  module ActiveRecord
    module ConnectionAdapters
      module PostgreSQL
        module OID
          class Array
            def initialize(element_type)
              @element_type = element_type
            end
            attr_reader :element_type
          end
        end
      end
    end
    module Type
      class String
        def self.new = new_singleton
        @new_singleton = nil
        def self.new_singleton = (@new_singleton ||= allocate)
      end
      class Integer < String; end
      class Float < String; end
      class Boolean < String; end
    end
    module Relation
      class QueryAttribute
        def initialize(name, value, type)
          @name, @value, @type = name, value, type
        end
        attr_reader :name, :value, :type
      end
    end
  end
end

require_relative '../../extensions/jade_sql/lib/jade-sql'
require_relative '../../extensions/jade_sql/lib/jade-sql/runtime'

describe JadeSql::Runtime do
  describe '.adapt_sql' do
    let(:pg_conn)     { double('PGConnection',     adapter_name: 'PostgreSQL') }
    let(:sqlite_conn) { double('SQLiteConnection', adapter_name: 'SQLite') }
    let(:mysql_conn)  { double('MySQLConnection',  adapter_name: 'Mysql2') }

    it 'rewrites ? placeholders to $1, $2, ... on Postgres' do
      sql = "SELECT * FROM patients WHERE name = ? AND balance > ?"
      expect(described_class.adapt_sql(sql, pg_conn))
        .to eql "SELECT * FROM patients WHERE name = $1 AND balance > $2"
    end

    it 'leaves SQL untouched on SQLite' do
      sql = "SELECT * FROM patients WHERE id = ?"
      expect(described_class.adapt_sql(sql, sqlite_conn)).to eql sql
    end

    it 'leaves SQL untouched on MySQL' do
      sql = "SELECT * FROM patients WHERE id = ?"
      expect(described_class.adapt_sql(sql, mysql_conn)).to eql sql
    end

    it 'handles SQL with no placeholders' do
      sql = "SELECT COUNT(*) FROM patients"
      expect(described_class.adapt_sql(sql, pg_conn)).to eql sql
    end
  end

  describe '.coerce_row' do
    it 'converts ::Date values to ISO date strings' do
      row = { "id" => 1, "occurred_on" => ::Date.new(2026, 5, 18) }
      expect(described_class.coerce_row(row)).to eql({
        "id" => 1,
        "occurred_on" => "2026-05-18",
      })
    end

    it 'converts ::Time values to ISO timestamp strings' do
      row = { "created_at" => ::Time.utc(2026, 5, 18, 12, 30, 45) }
      expect(described_class.coerce_row(row)).to eql({
        "created_at" => "2026-05-18T12:30:45Z",
      })
    end

    it 'converts ::DateTime values to ISO timestamp strings' do
      row = { "created_at" => ::DateTime.new(2026, 5, 18, 12, 30, 45) }
      expect(described_class.coerce_row(row)).to eql({
        "created_at" => "2026-05-18T12:30:45+00:00",
      })
    end

    it 'leaves other values untouched' do
      row = { "id" => 1, "name" => "Paul", "balance" => 100, "active" => true, "extra" => nil }
      expect(described_class.coerce_row(row)).to eql(row)
    end

    it 'parses Postgres array literals into Ruby Arrays' do
      row = { "id" => 1, "tags" => "{food,fun}" }
      expect(described_class.coerce_row(row)).to eql({
        "id" => 1,
        "tags" => ["food", "fun"],
      })
    end

    it 'parses an empty array literal as []' do
      expect(described_class.coerce_row({ "tags" => "{}" })).to eql({ "tags" => [] })
    end

    it 'handles quoted elements with embedded commas' do
      expect(described_class.coerce_row({ "tags" => '{"a,b","c d","e"}' }))
        .to eql({ "tags" => ["a,b", "c d", "e"] })
    end

    it 'handles escaped quotes and backslashes inside quoted elements' do
      expect(described_class.coerce_row({ "tags" => '{"a\\"b","c\\\\d"}' }))
        .to eql({ "tags" => ['a"b', 'c\\d'] })
    end

    it 'decodes NULL elements to nil' do
      expect(described_class.coerce_row({ "tags" => "{a,NULL,b}" }))
        .to eql({ "tags" => ["a", nil, "b"] })
    end

    it 'leaves strings that look like JSON objects alone' do
      expect(described_class.coerce_row({ "blob" => '{"k":"v"}' }))
        .to eql({ "blob" => '{"k":"v"}' })
    end

    it 'leaves nested JSON objects alone' do
      expect(described_class.coerce_row({ "blob" => '{"a":{"b":1}}' }))
        .to eql({ "blob" => '{"a":{"b":1}}' })
    end
  end

  describe '.typed_params' do
    let(:pg_conn)     { double('PGConnection',     adapter_name: 'PostgreSQL') }
    let(:sqlite_conn) { double('SQLiteConnection', adapter_name: 'SQLite') }

    it 'passes scalars through unchanged on Postgres' do
      expect(described_class.typed_params([1, "x", true, nil], pg_conn))
        .to eql [1, "x", true, nil]
    end

    it 'wraps arrays in QueryAttribute with OID::Array on Postgres' do
      out = described_class.typed_params([["food", "fun"]], pg_conn)
      expect(out.first).to be_a(::ActiveRecord::Relation::QueryAttribute)
      expect(out.first.value).to eql ["food", "fun"]
      expect(out.first.type).to be_a(::ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array)
      expect(out.first.type.element_type).to be_a(::ActiveRecord::Type::String)
    end

    it 'sniffs the element type from the first non-nil entry' do
      out = described_class.typed_params([[1, 2, 3]], pg_conn)
      expect(out.first.type.element_type).to be_a(::ActiveRecord::Type::Integer)
    end

    it 'falls back to text for an empty array' do
      out = described_class.typed_params([[]], pg_conn)
      expect(out.first.type.element_type).to be_a(::ActiveRecord::Type::String)
    end

    it 'leaves params untouched on non-Postgres adapters' do
      expect(described_class.typed_params([["a", "b"]], sqlite_conn))
        .to eql [["a", "b"]]
    end
  end
end
