require 'spec_helper'

# We want to test the placeholder rewrite without booting AR.
# Stub `ActiveRecord` enough that the runtime file loads.
unless defined?(::ActiveRecord)
  module ActiveRecord
    class Base; end
    class StatementInvalid < StandardError; end
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
  end
end
